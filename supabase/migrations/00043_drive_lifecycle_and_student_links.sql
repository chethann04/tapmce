-- =============================================================
-- MIGRATION 00043: Drive Lifecycle, Deletion & Student Professional Links
-- =============================================================

-- 1. Add LinkedIn & GitHub URLs to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS linkedin_url TEXT,
ADD COLUMN IF NOT EXISTS github_url TEXT;

-- 2. Add soft deletion columns to drives table
ALTER TABLE public.drives
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES public.profiles(id) DEFAULT NULL;

-- Create index on deleted_at for fast filtering
CREATE INDEX IF NOT EXISTS idx_drives_deleted_at ON public.drives(deleted_at);

-- 3. Update RLS policies for drives table
-- Ensure RLS is enabled
ALTER TABLE public.drives ENABLE ROW LEVEL SECURITY;

-- Drop old student view policy if existing to update it with deleted_at check
DROP POLICY IF EXISTS "Students can view active drives" ON public.drives;
DROP POLICY IF EXISTS "Anyone can view drives" ON public.drives;
DROP POLICY IF EXISTS "Authenticated users can view non-deleted drives" ON public.drives;

-- Authenticated users can view drives that are NOT soft-deleted
CREATE POLICY "Authenticated users can view non-deleted drives"
ON public.drives
FOR SELECT
TO authenticated
USING (
  deleted_at IS NULL
  OR EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('admin', 'tpo')
  )
);

-- TPO and Admin can insert drives
DROP POLICY IF EXISTS "TPO and Admin can insert drives" ON public.drives;
CREATE POLICY "TPO and Admin can insert drives"
ON public.drives
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('admin', 'tpo')
  )
);

-- TPO and Admin can update drives (including soft delete)
DROP POLICY IF EXISTS "TPO and Admin can update drives" ON public.drives;
CREATE POLICY "TPO and Admin can update drives"
ON public.drives
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('admin', 'tpo')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('admin', 'tpo')
  )
);

-- TPO and Admin can delete drives (hard delete if required)
DROP POLICY IF EXISTS "TPO and Admin can delete drives" ON public.drives;
CREATE POLICY "TPO and Admin can delete drives"
ON public.drives
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('admin', 'tpo')
  )
);

-- 4. Database-level validation on applications insert
CREATE OR REPLACE FUNCTION public.check_drive_application_eligibility()
RETURNS TRIGGER AS $$
DECLARE
  v_drive RECORD;
BEGIN
  SELECT * INTO v_drive FROM public.drives WHERE id = NEW.drive_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Placement drive does not exist.';
  END IF;

  IF v_drive.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'This placement drive has been deleted and is no longer accepting applications.';
  END IF;

  IF v_drive.status = 'upcoming' OR (v_drive.start_date IS NOT NULL AND v_drive.start_date > NOW()) THEN
    RAISE EXCEPTION 'Applications for this drive have not opened yet.';
  END IF;

  IF v_drive.status IN ('closed', 'completed', 'cancelled') OR (v_drive.end_date IS NOT NULL AND v_drive.end_date < NOW()) THEN
    RAISE EXCEPTION 'Applications for this drive are closed.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_drive_application ON public.applications;
CREATE TRIGGER trg_check_drive_application
BEFORE INSERT ON public.applications
FOR EACH ROW
EXECUTE FUNCTION public.check_drive_application_eligibility();
