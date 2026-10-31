-- Migration: 20260824000000_chat_realtime_publication_and_audit.sql
-- Description: Strict realtime publication check with clear notices and no swallowed errors

ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        RAISE NOTICE 'Publication supabase_realtime does not exist in this database environment. Skipping table addition.';
    ELSE
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_messages'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
        END IF;
    END IF;
END $$;
