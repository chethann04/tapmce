-- =============================================================================
-- Migration 00042: Strict Faculty Department Isolation & Hardened Profiles RLS
-- =============================================================================
-- 1. Creates secure functions for authenticating faculty role and department
-- 2. Enforces strict department isolation at the database/RLS layer
-- 3. Guarantees that faculty members can ONLY read and review students
--    belonging to their appointed department.
-- =============================================================================

-- 1. Helper function: Get user's role securely
CREATE OR REPLACE FUNCTION public.auth_role() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT role::text FROM public.profiles WHERE id = auth.uid();
$$;

-- 2. Helper function: Get faculty coordinator's assigned department
CREATE OR REPLACE FUNCTION public.auth_faculty_department() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT coalesce(p.department, fc.department, '')
  FROM public.profiles p
  LEFT JOIN public.faculty_coordinators fc ON fc.profile_id = p.id
  WHERE p.id = auth.uid();
$$;

-- 3. Helper function: Determine if student belongs to faculty's department
CREATE OR REPLACE FUNCTION public.is_student_in_faculty_dept(
  p_student_dept text,
  p_student_course_code text,
  p_student_course_name text,
  p_student_usn text
) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_fac_dept text;
  v_fac_code text;
  v_clean_fac_dept text;
  v_clean_stu_dept text;
BEGIN
  v_fac_dept := public.auth_faculty_department();
  IF v_fac_dept IS NULL OR trim(v_fac_dept) = '' THEN
    RETURN false;
  END IF;

  -- Normalize strings (lowercase, replace '&' with 'and', remove spaces)
  v_clean_fac_dept := lower(replace(replace(trim(v_fac_dept), '&', 'and'), ' ', ''));
  v_clean_stu_dept := lower(replace(replace(coalesce(trim(p_student_dept), ''), '&', 'and'), ' ', ''));

  -- A. Exact or substring match on department name
  IF v_clean_stu_dept <> '' AND (
    v_clean_stu_dept = v_clean_fac_dept OR 
    v_clean_stu_dept LIKE '%' || v_clean_fac_dept || '%' OR 
    v_clean_fac_dept LIKE '%' || v_clean_stu_dept || '%'
  ) THEN
    RETURN true;
  END IF;

  -- B. Match on detected or verified course name
  IF p_student_course_name IS NOT NULL THEN
    IF lower(replace(replace(trim(p_student_course_name), '&', 'and'), ' ', '')) = v_clean_fac_dept THEN
      RETURN true;
    END IF;
  END IF;

  -- C. Lookup branch/course code for faculty department from courses table
  SELECT course_code INTO v_fac_code
  FROM public.courses
  WHERE lower(replace(replace(course_name, '&', 'and'), ' ', '')) = v_clean_fac_dept
     OR course_name ILIKE '%' || v_fac_dept || '%'
  LIMIT 1;

  IF v_fac_code IS NOT NULL THEN
    IF p_student_course_code IS NOT NULL AND upper(trim(p_student_course_code)) = upper(trim(v_fac_code)) THEN
      RETURN true;
    END IF;
    IF p_student_usn IS NOT NULL AND upper(p_student_usn) ~ ('^[0-9][A-Z0-9]{2}[0-9]{2}' || upper(v_fac_code) || '[0-9]+$') THEN
      RETURN true;
    END IF;
  END IF;

  -- D. Lookup from departments table if courses table didn't match
  SELECT branch_code INTO v_fac_code
  FROM public.departments
  WHERE lower(replace(replace(name, '&', 'and'), ' ', '')) = v_clean_fac_dept
     OR name ILIKE '%' || v_fac_dept || '%'
  LIMIT 1;

  IF v_fac_code IS NOT NULL THEN
    IF p_student_course_code IS NOT NULL AND upper(trim(p_student_course_code)) = upper(trim(v_fac_code)) THEN
      RETURN true;
    END IF;
    IF p_student_usn IS NOT NULL AND upper(p_student_usn) ~ ('^[0-9][A-Z0-9]{2}[0-9]{2}' || upper(v_fac_code) || '[0-9]+$') THEN
      RETURN true;
    END IF;
  END IF;

  RETURN false;
END;
$$;

-- 4. Rebuild RLS policies on profiles table with strict department isolation
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow profile reads" ON public.profiles;
DROP POLICY IF EXISTS "Allow profile inserts" ON public.profiles;
DROP POLICY IF EXISTS "Allow profile updates" ON public.profiles;
DROP POLICY IF EXISTS profiles_self_select ON public.profiles;
DROP POLICY IF EXISTS profiles_self_insert ON public.profiles;
DROP POLICY IF EXISTS profiles_self_update ON public.profiles;
DROP POLICY IF EXISTS profiles_admin_all ON public.profiles;
DROP POLICY IF EXISTS profiles_tpo_update ON public.profiles;
DROP POLICY IF EXISTS "Admin/TPO view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Faculty view department students" ON public.profiles;
DROP POLICY IF EXISTS "Faculty update department students" ON public.profiles;

-- Authenticated users: view own profile
CREATE POLICY profiles_self_select ON public.profiles
  FOR SELECT USING (id = auth.uid());

-- Authenticated users: insert own profile
CREATE POLICY profiles_self_insert ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid() OR auth.role() = 'service_role');

-- Authenticated users: update own profile
CREATE POLICY profiles_self_update ON public.profiles
  FOR UPDATE USING (id = auth.uid() OR auth.role() = 'service_role')
  WITH CHECK (id = auth.uid() OR auth.role() = 'service_role');

-- Admin and TPO: View all profiles across the entire college
CREATE POLICY "Admin/TPO view all profiles" ON public.profiles
  FOR SELECT USING (
    auth_role() IN ('admin', 'tpo') OR auth.role() = 'service_role'
  );

-- Admin: Full management access
CREATE POLICY profiles_admin_all ON public.profiles
  FOR ALL USING (
    auth_role() = 'admin' OR auth.role() = 'service_role'
  );

-- TPO: Can update student and faculty profiles for coordinator assignments
CREATE POLICY profiles_tpo_update ON public.profiles
  FOR UPDATE USING (
    auth_role() = 'tpo'
  );

-- Faculty & Coordinators: Can ONLY SELECT students belonging to their own department
CREATE POLICY "Faculty view department students" ON public.profiles
  FOR SELECT USING (
    auth_role() IN ('faculty', 'faculty_coordinator')
    AND role = 'student'
    AND public.is_student_in_faculty_dept(department, detected_course_code, detected_course_name, usn)
  );

-- Faculty & Coordinators: Can ONLY UPDATE (verify, approve, reject) students belonging to their own department
CREATE POLICY "Faculty update department students" ON public.profiles
  FOR UPDATE USING (
    auth_role() IN ('faculty', 'faculty_coordinator')
    AND role = 'student'
    AND public.is_student_in_faculty_dept(department, detected_course_code, detected_course_name, usn)
  )
  WITH CHECK (
    auth_role() IN ('faculty', 'faculty_coordinator')
    AND role = 'student'
    AND public.is_student_in_faculty_dept(department, detected_course_code, detected_course_name, usn)
  );
