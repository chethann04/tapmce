-- =============================================================================
-- MIGRATION 00006: FIX INFINITE RECURSION IN RLS POLICIES FOR PROFILES, DRIVES & APPLICATIONS
-- =============================================================================

-- 1. Redefine auth_role(), auth_department(), auth_approval_status(), auth_consent_status() as SECURITY DEFINER
-- This ensures PostgreSQL evaluates user attributes without recursively triggering RLS policies on the profiles table.

CREATE OR REPLACE FUNCTION public.auth_role() RETURNS user_role
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.auth_department() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT department FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.auth_approval_status() RETURNS approval_status
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT approval_status FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.auth_consent_status() RETURNS consent_status
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT consent_status FROM public.profiles WHERE id = auth.uid();
$$;

-- 2. Clean up & re-create Profiles RLS policies safely

DROP POLICY IF EXISTS profiles_self_select ON public.profiles;
CREATE POLICY profiles_self_select ON public.profiles FOR SELECT USING (id = auth.uid());

DROP POLICY IF EXISTS profiles_admin_all ON public.profiles;
CREATE POLICY profiles_admin_all ON public.profiles FOR ALL USING (auth_role() = 'admin');

DROP POLICY IF EXISTS profiles_tpo_select ON public.profiles;
CREATE POLICY profiles_tpo_select ON public.profiles FOR SELECT USING (auth_role() = 'tpo');

DROP POLICY IF EXISTS profiles_tpo_update_faculty ON public.profiles;
CREATE POLICY profiles_tpo_update_faculty ON public.profiles FOR UPDATE USING (
  auth_role() = 'tpo' AND role IN ('faculty_coordinator','faculty','student')
);

DROP POLICY IF EXISTS profiles_faculty_select_dept ON public.profiles;
CREATE POLICY profiles_faculty_select_dept ON public.profiles FOR SELECT USING (
  auth_role() IN ('faculty_coordinator','faculty') AND role = 'student' AND department = auth_department()
);

DROP POLICY IF EXISTS profiles_faculty_approve_dept ON public.profiles;
CREATE POLICY profiles_faculty_approve_dept ON public.profiles FOR UPDATE USING (
  auth_role() IN ('faculty_coordinator','faculty') AND role = 'student' AND department = auth_department()
);

DROP POLICY IF EXISTS profiles_student_update_self ON public.profiles;
CREATE POLICY profiles_student_update_self ON public.profiles FOR UPDATE USING (
  id = auth.uid() AND auth_role() = 'student'
);

DROP POLICY IF EXISTS "Faculty view department students" ON public.profiles;
CREATE POLICY "Faculty view department students" ON public.profiles FOR SELECT USING (
  auth_role() IN ('faculty', 'faculty_coordinator') AND role = 'student' AND department = auth_department()
);

DROP POLICY IF EXISTS "Admin/TPO view all profiles" ON public.profiles;
CREATE POLICY "Admin/TPO view all profiles" ON public.profiles FOR SELECT USING (
  auth_role() IN ('admin', 'tpo')
);

-- 3. Update Drives RLS Policy (Prevent recursion when student reads drives)
DROP POLICY IF EXISTS drives_read_approved_students ON public.drives;
CREATE POLICY drives_read_approved_students ON public.drives FOR SELECT USING (
  auth_role() IN ('admin','tpo','faculty_coordinator','faculty')
  OR (auth_role() = 'student' AND auth_approval_status() = 'approved')
);

-- 4. Update Applications RLS Policy (Prevent recursion when inserting/reading applications)
DROP POLICY IF EXISTS applications_student_insert ON public.applications;
CREATE POLICY applications_student_insert ON public.applications FOR INSERT WITH CHECK (
  student_id = auth.uid()
  AND auth_approval_status() = 'approved'
  AND auth_consent_status() = 'opted_in'
);

DROP POLICY IF EXISTS applications_faculty_select_dept ON public.applications;
CREATE POLICY applications_faculty_select_dept ON public.applications FOR SELECT USING (
  auth_role() IN ('faculty_coordinator','faculty')
);