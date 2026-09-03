-- ============================================================
-- Migration 00028: Master Courses and Automatic Branch Recognition
-- ============================================================
-- 1. Creates centralized `courses` master table
-- 2. Seeds all 50 official UG Engineering programs with course codes & categories
-- 3. Adds USN-derived and faculty-verified course tracking to `profiles`
-- 4. Sets up RLS policies & helper lookup functions
-- ============================================================

-- ── 1. Create courses master table ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.courses (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_name  text NOT NULL,
  course_code  text NOT NULL UNIQUE,
  category     text NOT NULL,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- ── 2. Seed all 50 official UG Engineering Programs ───────────
INSERT INTO public.courses (course_name, course_code, category) VALUES
  ('Civil Engineering',                                           'CV', 'Civil / Construction / Mining'),
  ('Ceramics and Cement Technology',                              'CC', 'Civil / Construction / Mining'),
  ('Construction Technology & Management',                        'CT', 'Civil / Construction / Mining'),
  ('Environmental Engineering',                                   'EV', 'Civil / Construction / Mining'),
  ('Mining Engineering',                                          'MI', 'Civil / Construction / Mining'),
  ('Computer Science & Engineering',                              'CS', 'Computer Science / Computing'),
  ('Computer Engineering',                                        'CE', 'Computer Science / Computing'),
  ('Artificial Intelligence & Data Science',                      'AD', 'Computer Science / Computing'),
  ('Artificial Intelligence and Machine Learning',                'AI', 'Computer Science / Computing'),
  ('Biotechnology',                                               'BT', 'Other Engineering'),
  ('Computer & Communication Engineering',                        'CM', 'Computer Science / Computing'),
  ('Computer Science & Business System',                          'CB', 'Computer Science / Computing'),
  ('Computer Science & Design',                                   'CG', 'Computer Science / Computing'),
  ('Computer Science & Engineering (IoT)',                        'CO', 'Computer Science / Computing'),
  ('CSE (Artificial Intelligence & Machine Learning)',            'CI', 'Computer Science / Computing'),
  ('CSE (Artificial Intelligence)',                               'CA', 'Computer Science / Computing'),
  ('CSE (Cyber Security)',                                        'CY', 'Computer Science / Computing'),
  ('CSE (Data Science)',                                          'CD', 'Computer Science / Computing'),
  ('CSE (IoT & Cyber Security including Block Chain Technology)', 'IC', 'Computer Science / Computing'),
  ('Data Science',                                                'DS', 'Computer Science / Computing'),
  ('Information Science & Engineering',                           'IS', 'Computer Science / Computing'),
  ('Electronics & Communication Engineering',                     'EC', 'Electronics / Electrical'),
  ('Biomedical Engineering',                                      'BM', 'Electronics / Electrical'),
  ('Electrical & Electronics Engineering',                        'EE', 'Electronics / Electrical'),
  ('Electronics & Instrumentation Engineering',                   'EI', 'Electronics / Electrical'),
  ('Electronics & Telecommunication Engineering',                 'ET', 'Electronics / Electrical'),
  ('Industrial IoT',                                              'IO', 'Electronics / Electrical'),
  ('Medical Electronics Engineering',                             'ML', 'Electronics / Electrical'),
  ('Electronics Engineering (VLSI Design and Technology)',        'VL', 'Electronics / Electrical'),
  ('Electronics & Computer Engineering',                          'UE', 'Electronics / Electrical'),
  ('Aeronautical Engineering',                                    'AE', 'Mechanical / Industrial / Manufacturing'),
  ('Aerospace Engineering',                                       'AS', 'Mechanical / Industrial / Manufacturing'),
  ('Agricultural Engineering',                                    'AG', 'Other Engineering'),
  ('Automation and Robotics',                                     'AR', 'Mechanical / Industrial / Manufacturing'),
  ('Automobile Engineering',                                      'AU', 'Mechanical / Industrial / Manufacturing'),
  ('Chemical Engineering',                                        'CH', 'Other Engineering'),
  ('Industrial & Production Engineering',                         'IP', 'Mechanical / Industrial / Manufacturing'),
  ('Industrial Engineering & Management',                         'IM', 'Mechanical / Industrial / Manufacturing'),
  ('Manufacturing Science & Engineering',                         'MS', 'Mechanical / Industrial / Manufacturing'),
  ('Marine Engineering',                                          'MR', 'Mechanical / Industrial / Manufacturing'),
  ('Mechanical & Smart Manufacturing',                            'MM', 'Mechanical / Industrial / Manufacturing'),
  ('Mechanical Engineering',                                      'ME', 'Mechanical / Industrial / Manufacturing'),
  ('Mechatronics',                                                'MT', 'Mechanical / Industrial / Manufacturing'),
  ('Petrochem Engineering',                                       'PC', 'Other Engineering'),
  ('Robotics & Automation',                                       'RA', 'Mechanical / Industrial / Manufacturing'),
  ('Robotics and Artificial Intelligence',                        'RI', 'Mechanical / Industrial / Manufacturing'),
  ('Silk Technology',                                             'ST', 'Other Engineering'),
  ('Textile Technology',                                          'TX', 'Other Engineering'),
  ('Energy Engineering',                                          'ER', 'Other Engineering'),
  ('Smart Agritech',                                              'SA', 'Other Engineering')
ON CONFLICT (course_code) DO UPDATE SET
  course_name = EXCLUDED.course_name,
  category = EXCLUDED.category,
  updated_at = now();

-- ── 3. Add course tracking columns to profiles ────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS detected_course_id uuid REFERENCES public.courses(id);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS detected_course_code text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS detected_course_name text;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified_course_id uuid REFERENCES public.courses(id);
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified_course_code text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS verified_course_name text;

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS branch_source text DEFAULT 'usn' CHECK (branch_source IN ('usn', 'faculty', 'admin'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS branch_verified boolean DEFAULT false;

-- ── 4. RLS for courses table ──────────────────────────────────
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read courses" ON public.courses;
CREATE POLICY "Authenticated users can read courses"
  ON public.courses FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admin can manage courses" ON public.courses;
CREATE POLICY "Admin can manage courses"
  ON public.courses FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ── 5. Ensure legacy departments table has required columns and sync ──
ALTER TABLE public.departments ADD COLUMN IF NOT EXISTS branch_code text;
ALTER TABLE public.departments ADD COLUMN IF NOT EXISTS code text;
ALTER TABLE public.departments ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

-- Drop strict NOT NULL constraint on code column if previously present
ALTER TABLE public.departments ALTER COLUMN code DROP NOT NULL;

-- Safely sync into departments without requiring an existing unique constraint
INSERT INTO public.departments (name, branch_code, code, is_active)
SELECT c.course_name, c.course_code, c.course_code, c.is_active
FROM public.courses c
WHERE NOT EXISTS (
  SELECT 1 FROM public.departments d
  WHERE d.name = c.course_name OR d.branch_code = c.course_code
);

UPDATE public.departments d
SET 
  branch_code = c.course_code,
  code = c.course_code,
  is_active = c.is_active
FROM public.courses c
WHERE d.name = c.course_name;
