-- =============================================================================
-- Migration 00032: Fix Auth Hook/Query Error on Sign In
-- =============================================================================
-- Resolves "Database error querying schema" (500) during Supabase sign in.
-- 1. Drops any auth-schema triggers or custom schema hooks on auth.users
-- 2. Ensures search_path is explicitly set on all helper functions
-- 3. Verifies profiles table RLS doesn't block auth user token minting
-- =============================================================================

-- 1. Clean all potential triggers on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
DROP TRIGGER IF EXISTS trg_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- 2. Re-create helper security-definer functions with explicit search_path
CREATE OR REPLACE FUNCTION public.auth_role() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT role::text FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.auth_department() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT department FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.auth_approval_status() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT approval_status::text FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.auth_consent_status() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT consent_status::text FROM public.profiles WHERE id = auth.uid();
$$;

-- 3. Reset RLS policies on profiles cleanly
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_self_select ON public.profiles;
CREATE POLICY profiles_self_select ON public.profiles
  FOR SELECT USING (id = auth.uid());

DROP POLICY IF EXISTS profiles_self_insert ON public.profiles;
CREATE POLICY profiles_self_insert ON public.profiles
  FOR INSERT WITH CHECK (id = auth.uid() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS profiles_self_update ON public.profiles;
CREATE POLICY profiles_self_update ON public.profiles
  FOR UPDATE USING (id = auth.uid() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS profiles_admin_all ON public.profiles;
CREATE POLICY profiles_admin_all ON public.profiles
  FOR ALL USING (
    auth_role() = 'admin' OR auth.role() = 'service_role'
  );

DROP POLICY IF EXISTS "Admin/TPO view all profiles" ON public.profiles;
CREATE POLICY "Admin/TPO view all profiles" ON public.profiles
  FOR SELECT USING (
    auth_role() IN ('admin', 'tpo')
  );

DROP POLICY IF EXISTS "Faculty view department students" ON public.profiles;
CREATE POLICY "Faculty view department students" ON public.profiles
  FOR SELECT USING (
    auth_role() IN ('faculty', 'faculty_coordinator')
  );

-- 4. Clean Upsert Function for Demo Users
CREATE OR REPLACE FUNCTION public.seed_staff_account(
  p_email text,
  p_password text,
  p_name text,
  p_role text,
  p_dept text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
  v_uid uuid;
BEGIN
  SELECT id INTO v_uid FROM auth.users WHERE email = p_email;

  IF v_uid IS NULL THEN
    v_uid := gen_random_uuid();
    INSERT INTO auth.users (
      id,
      instance_id,
      email,
      encrypted_password,
      email_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      role,
      aud
    ) VALUES (
      v_uid,
      '00000000-0000-0000-0000-000000000000',
      p_email,
      crypt(p_password, gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('name', p_name, 'full_name', p_name, 'role', p_role, 'department', p_dept),
      now(),
      now(),
      'authenticated',
      'authenticated'
    );
  ELSE
    UPDATE auth.users
    SET 
      encrypted_password = crypt(p_password, gen_salt('bf')),
      email_confirmed_at = coalesce(email_confirmed_at, now()),
      raw_user_meta_data = jsonb_build_object('name', p_name, 'full_name', p_name, 'role', p_role, 'department', p_dept),
      updated_at = now()
    WHERE id = v_uid;
  END IF;

  -- Upsert Profile
  INSERT INTO public.profiles (
    id,
    email,
    name,
    role,
    department,
    approval_status,
    email_verified,
    profile_completed,
    created_at,
    updated_at
  ) VALUES (
    v_uid,
    p_email,
    p_name,
    p_role::user_role,
    p_dept,
    'approved',
    true,
    true,
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = EXCLUDED.name,
    role = EXCLUDED.role,
    department = coalesce(EXCLUDED.department, public.profiles.department),
    approval_status = 'approved',
    email_verified = true,
    profile_completed = true,
    updated_at = now();

  -- Faculty Coordinator Registration
  IF p_role = 'faculty_coordinator' AND p_dept IS NOT NULL THEN
    INSERT INTO public.faculty_coordinators (profile_id, department, appointed_by)
    VALUES (v_uid, p_dept, v_uid)
    ON CONFLICT (profile_id) DO UPDATE SET
      department = EXCLUDED.department;
  END IF;

  RETURN v_uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- 5. Seed all 4 accounts cleanly
SELECT public.seed_staff_account('admin@mcehassan.ac.in', 'admin@123', 'System Admin', 'admin');
SELECT public.seed_staff_account('tap@mcehassan.ac.in', 'tap@123', 'TPO Officer', 'tpo');
SELECT public.seed_staff_account('facultyise@mcehassan.ac.in', 'ise@123', 'Dr. ISE Faculty Coordinator', 'faculty_coordinator', 'Information Science & Engineering');
SELECT public.seed_staff_account('facultycse@mcehassan.ac.in', 'cse@123', 'Dr. CSE Faculty Coordinator', 'faculty_coordinator', 'Computer Science & Engineering');
