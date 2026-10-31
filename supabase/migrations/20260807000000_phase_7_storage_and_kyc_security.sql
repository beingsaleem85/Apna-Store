-- ============================================================================
-- MIGRATION: 20260807000000_phase_7_storage_and_kyc_security.sql
-- PURPOSE: Supabase Storage Security, Private KYC Bucket, Signed URLs, and Complete Seller Lifecycle
-- ============================================================================

-- 1. Ensure Storage Buckets Exist & Configured Correctly
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('kyc-documents', 'kyc-documents', FALSE, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
    ('seller-store-media', 'seller-store-media', TRUE, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET 
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Consolidate All Phase 7 Storage Path & Governance Columns into Single Canonical public.seller_kyc_documents & seller_stores
ALTER TABLE public.seller_kyc_documents
    ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS cnic_number TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS cnic_front_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS cnic_back_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS selfie_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS resubmission_instructions TEXT DEFAULT '';

ALTER TABLE public.seller_stores
    ADD COLUMN IF NOT EXISTS cnic_front_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS cnic_back_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS selfie_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS shop_logo_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS shop_banner_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS resubmission_instructions TEXT DEFAULT '';

-- 3. Safely Extend seller_stores.kyc_status CHECK Constraint to Include 'ResubmissionRequired'
ALTER TABLE public.seller_stores
    DROP CONSTRAINT IF EXISTS seller_stores_kyc_status_check;

ALTER TABLE public.seller_stores
    ADD CONSTRAINT seller_stores_kyc_status_check 
    CHECK (kyc_status IN ('Pending', 'Approved', 'Rejected', 'ResubmissionRequired'));

-- ----------------------------------------------------------------------------
-- RLS POLICIES FOR PRIVATE 'kyc-documents' BUCKET
-- ----------------------------------------------------------------------------

-- A. Public / Anonymous Read Denied
DROP POLICY IF EXISTS "Public read on kyc-documents denied" ON storage.objects;
CREATE POLICY "Public read on kyc-documents denied"
    ON storage.objects FOR SELECT
    TO anon
    USING (FALSE);

-- B. Authenticated Owner or Admin with 'kyc:view' Can Read KYC Objects
DROP POLICY IF EXISTS "Owner or KYC Admin can view KYC storage objects" ON storage.objects;
CREATE POLICY "Owner or KYC Admin can view KYC storage objects"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'kyc-documents'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.has_permission('kyc', 'view')
        )
    );

-- C. Authenticated Seller Can Insert into Own Folder in 'kyc-documents'
DROP POLICY IF EXISTS "Sellers can upload own KYC documents" ON storage.objects;
CREATE POLICY "Sellers can upload own KYC documents"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'kyc-documents'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- D. Owner or Admin Can Delete KYC Objects
DROP POLICY IF EXISTS "Owner or Admin can delete KYC documents" ON storage.objects;
CREATE POLICY "Owner or Admin can delete KYC documents"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'kyc-documents'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.has_permission('kyc', 'verify')
        )
    );

-- ----------------------------------------------------------------------------
-- RLS POLICIES FOR PUBLIC 'seller-store-media' BUCKET
-- ----------------------------------------------------------------------------

-- A. Anyone (Public & Anon) Can View Seller Store Logos & Banners
DROP POLICY IF EXISTS "Public can view seller store media" ON storage.objects;
CREATE POLICY "Public can view seller store media"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'seller-store-media');

-- B. Authenticated Seller Can Upload Store Media to Own Folder
DROP POLICY IF EXISTS "Sellers can upload own store media" ON storage.objects;
CREATE POLICY "Sellers can upload own store media"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'seller-store-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- C. Authenticated Seller Can Update Own Store Media
DROP POLICY IF EXISTS "Sellers can update own store media" ON storage.objects;
CREATE POLICY "Sellers can update own store media"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'seller-store-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ----------------------------------------------------------------------------
-- 4. HARDENED SECURITY DEFINER RPC: VERIFY & AUTHORIZE KYC ACCESS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.authorize_kyc_document_access(p_owner_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Owner can access own document
    IF auth.uid() = p_owner_id THEN
        RETURN TRUE;
    END IF;

    -- Admin with 'kyc:view' permission can access
    RETURN public.has_permission('kyc', 'view');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.authorize_kyc_document_access(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. HARDENED & RETROFITTED SELLER APPLICATION REVIEW RPC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_review_seller_application(
    p_store_id UUID,
    p_decision TEXT,
    p_reason TEXT DEFAULT '',
    p_resubmission_instructions TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
    v_owner_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('sellers', 'approve') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for seller store review.';
    END IF;

    SELECT owner_id INTO v_owner_id
    FROM public.seller_stores
    WHERE id = p_store_id;

    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'Seller store not found.';
    END IF;

    -- Self-review check: Seller cannot review own application
    IF v_owner_id = auth.uid() THEN
        RAISE EXCEPTION 'Self-review of seller application is forbidden.';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected', 'ResubmissionRequired') THEN
        RAISE EXCEPTION 'Invalid review decision. Must be Approved, Rejected, or ResubmissionRequired.';
    END IF;

    -- Non-empty reason validation for Rejection or Resubmission
    IF p_decision IN ('Rejected', 'ResubmissionRequired') AND trim(COALESCE(p_reason, '')) = '' THEN
        RAISE EXCEPTION 'Rejection or resubmission request requires a non-empty reason.';
    END IF;

    IF p_decision = 'Approved' THEN
        UPDATE public.seller_stores
        SET is_approved = TRUE,
            kyc_status = 'Approved',
            is_verified = TRUE,
            rejection_reason = '',
            resubmission_instructions = '',
            updated_at = NOW()
        WHERE id = p_store_id;

        -- Provision trusted seller role upon approval
        INSERT INTO public.user_roles (user_id, role, granted_by)
        VALUES (v_owner_id, 'seller'::public.app_role, auth.uid())
        ON CONFLICT (user_id, role) DO UPDATE SET granted_at = NOW(), granted_by = auth.uid();

    ELSIF p_decision = 'Rejected' THEN
        UPDATE public.seller_stores
        SET is_approved = FALSE,
            kyc_status = 'Rejected',
            is_verified = FALSE,
            rejection_reason = trim(p_reason),
            resubmission_instructions = '',
            updated_at = NOW()
        WHERE id = p_store_id;

    ELSIF p_decision = 'ResubmissionRequired' THEN
        UPDATE public.seller_stores
        SET is_approved = FALSE,
            kyc_status = 'ResubmissionRequired',
            is_verified = FALSE,
            rejection_reason = trim(p_reason),
            resubmission_instructions = COALESCE(NULLIF(trim(p_resubmission_instructions), ''), trim(p_reason)),
            updated_at = NOW()
        WHERE id = p_store_id;
    END IF;

    -- Write immutable audit log entry
    PERFORM public.internal_record_audit_log(
        'seller_stores',
        p_store_id::text,
        'REVIEW_SELLER_APPLICATION',
        jsonb_build_object(
            'decision', p_decision,
            'reason', p_reason,
            'instructions', p_resubmission_instructions,
            'seller_owner_id', v_owner_id
        )
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.admin_review_seller_application(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. SELLER KYC RESUBMISSION RPC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seller_submit_kyc_resubmission(
    p_store_id UUID,
    p_cnic_front_path TEXT,
    p_cnic_back_path TEXT,
    p_selfie_path TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_owner_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    SELECT owner_id INTO v_owner_id
    FROM public.seller_stores
    WHERE id = p_store_id;

    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'Seller store not found.';
    END IF;

    IF v_owner_id <> auth.uid() THEN
        RAISE EXCEPTION 'Access denied: Cannot resubmit KYC for another seller.';
    END IF;

    UPDATE public.seller_stores
    SET cnic_front_path = p_cnic_front_path,
        cnic_back_path = p_cnic_back_path,
        selfie_path = p_selfie_path,
        kyc_status = 'Pending',
        is_approved = FALSE,
        rejection_reason = '',
        resubmission_instructions = '',
        updated_at = NOW()
    WHERE id = p_store_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.seller_submit_kyc_resubmission(UUID, TEXT, TEXT, TEXT) TO authenticated;
