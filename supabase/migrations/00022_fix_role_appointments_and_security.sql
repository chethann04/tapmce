-- =============================================================
-- MIGRATION 00022: Fix role-assignment bugs & RLS gaps
--
-- Problem:
--   1. admin_set_user_role was PUBLICLY executable (no admin check)
--      — anyone with the anon key could flip any profile to tpo/admin.
--   2. Appointing a Faculty Coordinator never removed the user from
--      tpo_appointments (and vice versa), so coordinators kept showing
--      as TPO. The TPO list read tpo_appointments instead of profiles.role.
--   3. Admins had no INSERT/UPDATE/DELETE policy on faculty_coordinators,
--      so the admin "Appoint Faculty Coordinator" flow failed partway.
--   4. No INSERT policy on profiles meant sign-up upserts could silently fail.
-- =============================================================

-- 1. SECURE admin_set_user_role: only a logged-in admin may change roles.
--    The function stays SECURITY DEFINER (bypasses RLS to do the update),
--    but it now verifies the caller is an admin first.
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
  ) THEN
    RAISE EXCEPTION 'Only system administrators can change user roles';
  END IF;

  UPDATE public.profiles SET role = p_role::user_role WHERE id = p_profile_id;
END;
$$;

-- Restrict who may invoke it: authenticated users (the signed-in app),
-- never anon / public / service role via the client.
REVOKE EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) TO authenticated;

-- 2. RLS: admins need full access to faculty_coordinators so the admin
--    "Appoint Faculty Coordinator" flow (upsert + delete) works.
DROP POLICY IF EXISTS fc_admin_all ON public.faculty_coordinators;
CREATE POLICY fc_admin_all ON public.faculty_coordinators
  FOR ALL USING (auth_role() = 'admin');

-- 3. RLS: TPOs may delete tpo_appointments rows so that appointing a
--    faculty coordinator removes any stale TPO appointment.
DROP POLICY IF EXISTS tpo_appt_tpo_delete ON public.tpo_appointments;
CREATE POLICY tpo_appt_tpo_delete ON public.tpo_appointments
  FOR DELETE USING (auth_role() = 'tpo');

-- 4. RLS: allow a user to create their OWN profile row during sign-up so
--    profile upserts stop silently failing. Privileged roles (admin/tpo)
--    are excluded — they can only be granted through an admin appointment.
DROP POLICY IF EXISTS profiles_self_insert ON public.profiles;
CREATE POLICY profiles_self_insert ON public.profiles
  FOR INSERT WITH CHECK (
    id = auth.uid() AND role IN ('student', 'faculty')
  );

-- 5. DATA HYGIENE: the TPO list now reads profiles.role (not
--    tpo_appointments). Remove appointment rows that no longer match the
--    user's actual role so stale records can't surface as TPO/coordinator.
DELETE FROM public.tpo_appointments t
WHERE NOT EXISTS (
  SELECT 1 FROM public.profiles p
  WHERE p.id = t.profile_id AND p.role = 'tpo'
);

DELETE FROM public.faculty_coordinators f
WHERE NOT EXISTS (
  SELECT 1 FROM public.profiles p
  WHERE p.id = f.profile_id AND p.role = 'faculty_coordinator'
);
