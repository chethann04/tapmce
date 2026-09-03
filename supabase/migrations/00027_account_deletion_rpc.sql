-- Migration 00027: Account Deletion RPC and Security Hardening
-- Allows students to request self-service account deletion (soft anonymization + auth deletion)

CREATE OR REPLACE FUNCTION delete_user_account(target_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  calling_user_id UUID;
  user_role TEXT;
BEGIN
  calling_user_id := auth.uid();

  -- Verify calling user is deleting their own account or is an admin/tpo
  SELECT role INTO user_role FROM public.profiles WHERE id = calling_user_id;

  IF calling_user_id != target_user_id AND user_role NOT IN ('admin', 'tpo') THEN
    RAISE EXCEPTION 'Unauthorized account deletion request.';
  END IF;

  -- 1. Anonymize profile data to retain placement statistics while scrubbing PII
  UPDATE public.profiles
  SET 
    full_name = 'Deleted User',
    email = 'deleted_' || target_user_id || '@anonymized.local',
    phone = NULL,
    usn = NULL,
    resume_url = NULL,
    avatar_url = NULL,
    updated_at = NOW()
  WHERE id = target_user_id;

  -- 2. Clear FCM Tokens
  DELETE FROM public.fcm_tokens WHERE user_id = target_user_id;

  -- 3. Delete auth user record via Supabase auth schema
  DELETE FROM auth.users WHERE id = target_user_id;

  RETURN TRUE;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Error in delete_user_account: %', SQLERRM;
    RETURN FALSE;
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account(UUID) TO authenticated;
