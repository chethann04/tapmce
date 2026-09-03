-- ============================================================
-- Migration 00013: Add profile onboarding columns
-- ============================================================
-- Adds semester, section, admission_year, graduation_year,
-- and profile_completed to the profiles table.
-- ============================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS semester int;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS section text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS admission_year int;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS graduation_year int;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS profile_completed boolean DEFAULT false;
