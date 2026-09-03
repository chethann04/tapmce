-- =============================================================
-- MIGRATION 00019: Reconcile offers table schema (status column & student_id)
-- =============================================================

-- 1. Ensure status column exists (renaming decision to status if present)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'offers' AND column_name = 'decision'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'offers' AND column_name = 'status'
  ) THEN
    ALTER TABLE public.offers RENAME COLUMN decision TO status;
  ELSIF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'offers' AND column_name = 'status'
  ) THEN
    ALTER TABLE public.offers ADD COLUMN status text DEFAULT 'pending';
  END IF;
END $$;

-- 2. Add student_id column to offers if missing
ALTER TABLE public.offers ADD COLUMN IF NOT EXISTS student_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;

-- 3. Backfill student_id from applications table
UPDATE public.offers
SET student_id = applications.student_id
FROM public.applications
WHERE offers.application_id = applications.id
  AND offers.student_id IS NULL;
-- 4. Ensure drives table has role_title and ctc_or_stipend columns
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS role_title text;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS ctc_or_stipend text;
