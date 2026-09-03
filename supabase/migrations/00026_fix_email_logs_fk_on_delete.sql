-- =============================================================
-- MIGRATION 00026: Fix email_logs FK to allow profile deletion
-- =============================================================
-- The email_logs_created_by_fkey constraint was created without
-- ON DELETE SET NULL, blocking profile deletions. This migration
-- drops and recreates it with the correct behavior so that when
-- a profile is deleted, created_by is set to NULL (logs are kept).

ALTER TABLE public.email_logs
  DROP CONSTRAINT IF EXISTS email_logs_created_by_fkey;

ALTER TABLE public.email_logs
  ADD CONSTRAINT email_logs_created_by_fkey
  FOREIGN KEY (created_by)
  REFERENCES public.profiles(id)
  ON DELETE SET NULL;
