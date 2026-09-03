-- =============================================================
-- MIGRATION 00016: Fix schema conflicts and missing objects
-- =============================================================

-- 1. UNIFY drive_status ENUM (00001 has draft/open/closed/completed,
--    00002 has upcoming/ongoing/completed/cancelled — code uses all of them)
DROP TYPE IF EXISTS drive_status CASCADE;
CREATE TYPE drive_status AS ENUM (
  'draft', 'upcoming', 'open', 'ongoing', 'closed', 'completed', 'cancelled'
);

-- 2. UNIFY application_status ENUM (00001 has interview but not not_selected,
--    00002 has not_selected but not interview — code uses all)
DROP TYPE IF EXISTS application_status CASCADE;
CREATE TYPE application_status AS ENUM (
  'applied', 'shortlisted', 'interview', 'rejected', 'selected', 'not_selected'
);

-- 3. CREATE missing admin_set_user_role RPC function
--    (called by user_management_repository_impl.dart for TPO/FC appointment)
CREATE OR REPLACE FUNCTION public.admin_set_user_role(
  p_profile_id uuid,
  p_role text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles SET role = p_role::user_role WHERE id = p_profile_id;
END;
$$;

-- Restrict: only service_role can execute (bypasses RLS)
REVOKE EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) TO service_role;

-- 4. FIX offers table: code writes 'status' not 'decision', needs 'offered' value,
--    and uploaded_by should be nullable
ALTER TABLE public.offers DROP CONSTRAINT IF EXISTS offers_decision_check;
ALTER TABLE public.offers DROP COLUMN IF EXISTS status;
ALTER TABLE public.offers RENAME COLUMN decision TO status;
ALTER TABLE public.offers ALTER COLUMN status TYPE text;
ALTER TABLE public.offers ALTER COLUMN status SET DEFAULT 'pending';
ALTER TABLE public.offers ADD CONSTRAINT offers_status_check
  CHECK (status IN ('pending', 'offered', 'accepted', 'declined'));
ALTER TABLE public.offers ALTER COLUMN uploaded_by DROP NOT NULL;

-- 5. ADD missing index for getRoundStudents() performance
--    (queries .eq('current_round', roundNumber) on applications)
CREATE INDEX IF NOT EXISTS idx_applications_current_round
  ON public.applications(current_round);

-- 6. BROADEN notifications insert policy so admin can also send
DROP POLICY IF EXISTS notifications_tpo_insert ON public.notifications;
CREATE POLICY notifications_tpo_insert ON public.notifications
  FOR INSERT WITH CHECK (auth_role() IN ('tpo', 'admin'));

-- 7. RECONCILE companies table: add missing columns from 00002
--    that the code may reference (website, description)
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS website text;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS description text;

-- 8. RECONCILE drives table: ensure ALL columns from both migrations exist
--    00001 columns that 00002 lacks:
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS role_title text;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS job_description text;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS ctc_or_stipend text;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS cgpa_cutoff numeric;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS backlog_limit int;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS rounds_count int NOT NULL DEFAULT 0;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS application_deadline timestamptz;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES profiles(id);
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS updated_by uuid REFERENCES profiles(id);

--    00002 columns that 00001 lacks:
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS role text;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS package_lpa text;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS eligibility_cgpa numeric;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS end_date timestamptz;

-- Ensure eligibility_branches is jsonb (00001) not TEXT[] (00002)
-- If it's TEXT[], convert to jsonb
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'drives' AND column_name = 'eligibility_branches'
    AND udt_name = '_text'
  ) THEN
    ALTER TABLE public.drives DROP COLUMN eligibility_branches;
    ALTER TABLE public.drives ADD COLUMN eligibility_branches jsonb DEFAULT '[]'::jsonb;
  END IF;
END $$;

-- Ensure status column uses the unified enum
ALTER TABLE public.drives ALTER COLUMN status TYPE drive_status USING status::drive_status;
ALTER TABLE public.drives ALTER COLUMN status SET DEFAULT 'upcoming'::drive_status;

-- Ensure applications.status uses the unified enum
ALTER TABLE public.applications ALTER COLUMN status TYPE application_status USING status::application_status;
ALTER TABLE public.applications ALTER COLUMN status SET DEFAULT 'applied'::application_status;

-- Add missing current_round column (exists in 00001 schema but not in 00002)
ALTER TABLE public.applications ADD COLUMN IF NOT EXISTS current_round int DEFAULT 0;

-- Add missing updated_by column (exists in 00001 schema but not in 00002)
ALTER TABLE public.applications ADD COLUMN IF NOT EXISTS updated_by uuid REFERENCES profiles(id);
