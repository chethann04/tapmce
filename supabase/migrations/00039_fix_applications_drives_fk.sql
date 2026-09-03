-- =============================================================================
-- Migration 00039: Add Foreign Key from applications(drive_id) to drives(id)
-- =============================================================================

-- Ensure drives table exists
CREATE TABLE IF NOT EXISTS public.drives (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid REFERENCES public.companies(id) ON DELETE SET NULL,
  title text,
  role text,
  package_lpa numeric,
  status text DEFAULT 'upcoming',
  created_at timestamptz DEFAULT now()
);

-- Ensure applications table exists
CREATE TABLE IF NOT EXISTS public.applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drive_id uuid,
  student_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'applied',
  current_round int DEFAULT 0,
  resume_version_url text,
  applied_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Add explicit Foreign Key constraint so PostgREST schema cache recognizes the relationship
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'applications_drive_id_fkey'
    AND table_name = 'applications'
  ) THEN
    ALTER TABLE public.applications
    ADD CONSTRAINT applications_drive_id_fkey
    FOREIGN KEY (drive_id) REFERENCES public.drives(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Enable RLS and add public SELECT policies
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view applications" ON public.applications;
CREATE POLICY "Anyone can view applications" ON public.applications FOR SELECT USING (true);

ALTER TABLE public.drives ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view drives" ON public.drives;
CREATE POLICY "Anyone can view drives" ON public.drives FOR SELECT USING (true);

-- Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
