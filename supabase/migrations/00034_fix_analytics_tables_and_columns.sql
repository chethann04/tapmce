-- ============================================================
-- Migration 00034: Complete Master Tables & Column Schema Fix
-- ============================================================
-- Fixes all 5 missing tables & columns shown in the debug report:
-- 1. drives table & public read policy
-- 2. drive_rounds table & public read policy
-- 3. application_round_status table & public read policy
-- 4. drive_attendance table with status column
-- 5. offers table with ctc_offered and status columns
-- ============================================================

-- 1. COMPANIES Table
CREATE TABLE IF NOT EXISTS public.companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  logo_url text,
  industry text,
  website text,
  description text,
  hr_contact_name text,
  hr_contact_email text,
  hr_contact_phone text,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view companies" ON public.companies;
CREATE POLICY "Anyone can view companies" ON public.companies FOR SELECT USING (true);

-- 2. DRIVES Table
CREATE TABLE IF NOT EXISTS public.drives (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  academic_cycle_id uuid,
  role_title text NOT NULL DEFAULT 'Job Role',
  role text,
  ctc_or_stipend text,
  package_lpa text,
  job_description text,
  description text,
  eligibility_branches jsonb NOT NULL DEFAULT '[]',
  eligibility_cgpa numeric,
  cgpa_cutoff numeric(3,2),
  backlog_limit int DEFAULT 0,
  rounds_count int NOT NULL DEFAULT 1,
  application_deadline timestamptz,
  end_date timestamptz,
  status text NOT NULL DEFAULT 'open',
  created_by uuid REFERENCES public.profiles(id),
  updated_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS role text;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS role_title text DEFAULT 'Job Role';
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS package_lpa text;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS end_date timestamptz;
ALTER TABLE public.drives ADD COLUMN IF NOT EXISTS status text DEFAULT 'open';

ALTER TABLE public.drives ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view drives" ON public.drives;
CREATE POLICY "Anyone can view drives" ON public.drives FOR SELECT USING (true);

-- 3. DRIVE_ROUNDS Table
CREATE TABLE IF NOT EXISTS public.drive_rounds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drive_id uuid NOT NULL REFERENCES public.drives(id) ON DELETE CASCADE,
  round_number int NOT NULL,
  round_name text NOT NULL,
  round_date date,
  round_time time,
  venue_or_link text,
  created_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(drive_id, round_number)
);

ALTER TABLE public.drive_rounds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view drive rounds" ON public.drive_rounds;
CREATE POLICY "Anyone can view drive rounds" ON public.drive_rounds FOR SELECT USING (true);

-- 4. APPLICATIONS Table
CREATE TABLE IF NOT EXISTS public.applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drive_id uuid NOT NULL REFERENCES public.drives(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'applied',
  current_round int DEFAULT 0,
  resume_version_url text,
  why_this_role text,
  applied_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.profiles(id),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(drive_id, student_id)
);

ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view applications" ON public.applications;
CREATE POLICY "Anyone can view applications" ON public.applications FOR SELECT USING (true);

-- 5. APPLICATION_ROUND_STATUS Table
CREATE TABLE IF NOT EXISTS public.application_round_status (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  round_id uuid NOT NULL REFERENCES public.drive_rounds(id) ON DELETE CASCADE,
  attended boolean DEFAULT false,
  result text DEFAULT 'pending',
  updated_by uuid REFERENCES public.profiles(id),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(application_id, round_id)
);

ALTER TABLE public.application_round_status ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view application round status" ON public.application_round_status;
CREATE POLICY "Anyone can view application round status" ON public.application_round_status FOR SELECT USING (true);

-- 6. DRIVE_ATTENDANCE Table
CREATE TABLE IF NOT EXISTS public.drive_attendance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drive_id uuid NOT NULL REFERENCES public.drives(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  scanned_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'present',
  UNIQUE(drive_id, student_id)
);

ALTER TABLE public.drive_attendance ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'present';

ALTER TABLE public.drive_attendance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view drive attendance" ON public.drive_attendance;
CREATE POLICY "Anyone can view drive attendance" ON public.drive_attendance FOR SELECT USING (true);

-- 7. OFFERS Table
CREATE TABLE IF NOT EXISTS public.offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  student_id uuid REFERENCES public.profiles(id),
  ctc_offered text,
  status text NOT NULL DEFAULT 'pending',
  offer_letter_url text,
  joining_date date,
  uploaded_by uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.offers ADD COLUMN IF NOT EXISTS ctc_offered text;
ALTER TABLE public.offers ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending';

ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can view offers" ON public.offers;
CREATE POLICY "Anyone can view offers" ON public.offers FOR SELECT USING (true);
