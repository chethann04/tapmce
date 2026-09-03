-- =============================================================================
-- Migration 00037: Fix Profiles RLS for Verification & Direct Updates
-- =============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop all conflicting UPDATE policies on profiles
DROP POLICY IF EXISTS profiles_self_update ON public.profiles;
DROP POLICY IF EXISTS profiles_faculty_approve_dept ON public.profiles;
DROP POLICY IF EXISTS profiles_student_update_self ON public.profiles;
DROP POLICY IF EXISTS profiles_tpo_update_faculty ON public.profiles;
DROP POLICY IF EXISTS "Faculty approve students" ON public.profiles;
DROP POLICY IF EXISTS "Staff can review student approval" ON public.profiles;
DROP POLICY IF EXISTS "Allow profile updates" ON public.profiles;

-- Create single unified UPDATE policy on profiles
CREATE POLICY "Allow profile updates" ON public.profiles
  FOR UPDATE
  USING (true)
  WITH CHECK (true);
