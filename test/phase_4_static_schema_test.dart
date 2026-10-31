import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 4 — Static Database Schema & RLS Audit Tests', () {
    final migrationFile = File('supabase/migrations/20260805000000_authoritative_schema_and_rls.sql');
    final pgTapTestFile = File('supabase/tests/phase_4_rls_security_test.sql');

    test('1. Authoritative migration file exists', () {
      expect(migrationFile.existsSync(), isTrue, reason: 'Migration file 20260805000000_authoritative_schema_and_rls.sql must exist');
    });

    test('2. Prepared pgTAP runtime test file exists', () {
      expect(pgTapTestFile.existsSync(), isTrue, reason: 'Runtime test file supabase/tests/phase_4_rls_security_test.sql must exist');
    });

    test('3. Migration contains protected user_roles table & app_role enum', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, contains('CREATE TYPE public.app_role AS ENUM'));
      expect(sqlContent, contains('CREATE TABLE IF NOT EXISTS public.user_roles'));
      expect(sqlContent, contains('public.get_current_user_role()'));
    });

    test('4. SECURITY DEFINER functions specify SET search_path = \'\'', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, contains("SECURITY DEFINER SET search_path = ''"));
      expect(sqlContent, contains('REVOKE EXECUTE ON FUNCTION public.assign_user_role'));
    });

    test('5. handle_new_user trigger does NOT trust raw_user_meta_data for roles', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, contains("VALUES (new.id, 'buyer'::public.app_role)"));
      expect(sqlContent, isNot(contains("new.raw_user_meta_data->>'role'")));
    });

    test('6. Profiles table is private and public view uses security_invoker', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, contains('CREATE OR REPLACE VIEW public.public_profile_view'));
      expect(sqlContent, contains('security_invoker = true'));
      expect(sqlContent, contains('auth.uid() = id OR public.is_admin()'));
    });

    test('7. Admin review product function prevents seller self-approval', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, contains('public.admin_review_product'));
      expect(sqlContent, contains('Sellers cannot approve their own products'));
    });

    test('8. Column-level UPDATE grants and revokes are explicitly declared', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, contains('REVOKE ALL ON public.seller_stores FROM PUBLIC, anon, authenticated;'));
      expect(sqlContent, contains('GRANT UPDATE (shop_name, shop_slug'));
      expect(sqlContent, contains('REVOKE ALL ON public.products FROM PUBLIC, anon, authenticated;'));
      expect(sqlContent, contains('REVOKE ALL ON public.buyer_orders FROM PUBLIC, anon, authenticated;'));
    });

    test('9. Column-level INSERT grants exclude protected fields (is_approved, commission_rate, approval_status, status)', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, contains('GRANT INSERT (owner_id, shop_name, shop_slug'));
      expect(sqlContent, isNot(contains('GRANT INSERT (owner_id, shop_name, shop_slug, is_approved')));
      expect(sqlContent, contains('GRANT INSERT (seller_store_id, category_id, name'));
      expect(sqlContent, isNot(contains('GRANT INSERT (seller_store_id, category_id, name, approval_status')));
    });

    test('10. Direct buyer_orders client INSERT is revoked until Phase 8', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, contains('REVOKE ALL ON public.buyer_orders FROM PUBLIC, anon, authenticated;'));
      expect(sqlContent, contains('GRANT SELECT ON public.buyer_orders TO authenticated;'));
      expect(sqlContent, isNot(contains('GRANT INSERT ON public.buyer_orders TO authenticated;')));
    });

    test('11. user_roles has NO client INSERT, UPDATE, or DELETE access', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, contains('REVOKE ALL ON public.user_roles FROM PUBLIC, anon, authenticated;'));
      expect(sqlContent, contains('GRANT SELECT ON public.user_roles TO authenticated;'));
    });

    test('12. RLS is explicitly enabled on all canonical tables', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, contains('ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;'));
      expect(sqlContent, contains('ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;'));
      expect(sqlContent, contains('ALTER TABLE public.seller_stores ENABLE ROW LEVEL SECURITY;'));
      expect(sqlContent, contains('ALTER TABLE public.seller_kyc_documents ENABLE ROW LEVEL SECURITY;'));
      expect(sqlContent, contains('ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;'));
      expect(sqlContent, contains('ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;'));
      expect(sqlContent, contains('ALTER TABLE public.buyer_orders ENABLE ROW LEVEL SECURITY;'));
    });

    test('13. Migration excludes dangerous destructive SQL statements', () {
      final sqlContent = migrationFile.readAsStringSync();
      expect(sqlContent, isNot(contains('DROP SCHEMA public CASCADE')));
      expect(sqlContent, isNot(contains('DROP TABLE public.profiles CASCADE')));
      expect(sqlContent, isNot(contains('TRUNCATE')));
    });
  });
}
