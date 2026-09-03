-- ============================================================
-- Complete Master Seed Script for Demo Users & RPCs
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Create/replace admin_set_user_role RPC
CREATE OR REPLACE FUNCTION public.admin_set_user_role(
  p_profile_id uuid,
  p_role text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) AND auth.role() != 'service_role' THEN
    RAISE EXCEPTION 'Only system administrators can change user roles';
  END IF;

  UPDATE public.profiles
  SET 
    role = p_role::user_role,
    updated_at = now()
  WHERE id = p_profile_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) TO service_role;

-- 2. Seed function that handles both creation and password reset
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Execute seeding for all accounts
SELECT public.seed_staff_account('admin@mcehassan.ac.in', 'admin@123', 'System Admin', 'admin');
SELECT public.seed_staff_account('tap@mcehassan.ac.in', 'tap@123', 'TPO Officer', 'tpo');
SELECT public.seed_staff_account('facultyise@mcehassan.ac.in', 'ise@123', 'Dr. ISE Faculty Coordinator', 'faculty_coordinator', 'Information Science & Engineering');
SELECT public.seed_staff_account('facultycse@mcehassan.ac.in', 'cse@123', 'Dr. CSE Faculty Coordinator', 'faculty_coordinator', 'Computer Science & Engineering');
