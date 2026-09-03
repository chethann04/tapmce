-- ============================================================
-- Migration 00029: Seed Staff & Faculty Demo Accounts
-- ============================================================
-- Enables instant sign-in with password `Pass123!word` for:
-- 1. admin@mcehassan.ac.in (System Admin)
-- 2. tap@mcehassan.ac.in (TPO Officer)
-- 3. facultyise@mcehassan.ac.in (ISE Faculty Coordinator)
-- 4. facultycse@mcehassan.ac.in (CSE Faculty Coordinator)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Function to safely create or reset an auth user and profile
CREATE OR REPLACE FUNCTION public.seed_demo_user(
  p_email text,
  p_password text,
  p_name text,
  p_role text,
  p_department text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
  v_user_id uuid;
  v_encrypted_pw text;
BEGIN
  v_encrypted_pw := crypt(p_password, gen_salt('bf'));

  -- 1. Check if user already exists in auth.users
  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;

  IF v_user_id IS NULL THEN
    v_user_id := gen_random_uuid();
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
      v_user_id,
      '00000000-0000-0000-0000-000000000000',
      p_email,
      v_encrypted_pw,
      now(),
      '{"provider":"email","providers":["email"]}',
      jsonb_build_object('name', p_name, 'full_name', p_name, 'role', p_role, 'department', p_department),
      now(),
      now(),
      'authenticated',
      'authenticated'
    );
  ELSE
    -- Update existing user password and confirmation
    UPDATE auth.users
    SET 
      encrypted_password = v_encrypted_pw,
      email_confirmed_at = coalesce(email_confirmed_at, now()),
      raw_user_meta_data = jsonb_build_object('name', p_name, 'full_name', p_name, 'role', p_role, 'department', p_department),
      updated_at = now()
    WHERE id = v_user_id;
  END IF;

  -- 2. Upsert profile
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
    v_user_id,
    p_email,
    p_name,
    p_role::user_role,
    p_department,
    'approved',
    true,
    true,
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    role = EXCLUDED.role,
    department = coalesce(EXCLUDED.department, public.profiles.department),
    approval_status = 'approved',
    email_verified = true,
    updated_at = now();

  -- 3. If faculty coordinator, register in faculty_coordinators table
  IF p_role = 'faculty_coordinator' AND p_department IS NOT NULL THEN
    INSERT INTO public.faculty_coordinators (profile_id, department, appointed_by)
    VALUES (v_user_id, p_department, v_user_id)
    ON CONFLICT (profile_id) DO UPDATE SET
      department = EXCLUDED.department;
  END IF;

  RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute seeding for staff & faculty accounts with custom credentials
SELECT public.seed_demo_user(
  'admin@mcehassan.ac.in',
  'admin@123',
  'System Admin',
  'admin'
);

SELECT public.seed_demo_user(
  'tap@mcehassan.ac.in',
  'tap@123',
  'TPO Officer',
  'tpo'
);

SELECT public.seed_demo_user(
  'facultyise@mcehassan.ac.in',
  'ise@123',
  'Dr. ISE Faculty Coordinator',
  'faculty_coordinator',
  'Information Science & Engineering'
);

SELECT public.seed_demo_user(
  'facultycse@mcehassan.ac.in',
  'cse@123',
  'Dr. CSE Faculty Coordinator',
  'faculty_coordinator',
  'Computer Science & Engineering'
);
