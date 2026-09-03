-- ============================================================
-- Migration 00035: Add scanned_at Column to drive_attendance
-- ============================================================

ALTER TABLE public.drive_attendance 
  ADD COLUMN IF NOT EXISTS scanned_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
