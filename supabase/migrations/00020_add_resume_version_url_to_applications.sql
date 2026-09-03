-- =============================================================
-- MIGRATION 00020: Add resume_version_url column to applications
-- =============================================================

ALTER TABLE public.applications ADD COLUMN IF NOT EXISTS resume_version_url text;
