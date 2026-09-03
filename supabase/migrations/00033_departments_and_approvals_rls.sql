-- ============================================================
-- Migration 00033: Enable Public Read for Departments & Profiles RLS Fix
-- ============================================================

-- 1. Departments table: Allow ANY client to read active departments
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read departments" ON public.departments;
DROP POLICY IF EXISTS "Authenticated users can read departments" ON public.departments;
CREATE POLICY "Anyone can read departments" ON public.departments
  FOR SELECT USING (true);

-- 2. Courses table: Allow ANY client to read active UG courses
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read courses" ON public.courses;
CREATE POLICY "Anyone can read courses" ON public.courses
  FOR SELECT USING (true);

-- 3. Profiles table: Ensure students, staff, and faculty can read student profiles for approval
DROP POLICY IF EXISTS "Faculty view all pending students" ON public.profiles;
CREATE POLICY "Faculty view all pending students" ON public.profiles
  FOR SELECT USING (
    approval_status = 'pending' 
    OR id = auth.uid() 
    OR role IN ('admin', 'tpo', 'faculty_coordinator', 'faculty')
    OR auth.role() = 'service_role'
  );
