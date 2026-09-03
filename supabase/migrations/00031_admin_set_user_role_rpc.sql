-- ============================================================
-- Migration 00031: Create and Grant admin_set_user_role RPC
-- ============================================================
-- Allows Admin to assign TPO and Faculty Coordinator roles via Flutter RPC

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
  -- Verify caller is admin or service_role
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

-- Grant execution to authenticated users (the function itself verifies admin role above)
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(uuid, text) TO service_role;
