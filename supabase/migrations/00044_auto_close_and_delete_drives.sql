-- =============================================================
-- MIGRATION 00044: Auto Close Drives on Deadline & Auto Delete After 1 Week
-- =============================================================

CREATE OR REPLACE FUNCTION public.auto_update_drive_statuses()
RETURNS void AS $body$
BEGIN
  -- 1. Auto-open upcoming drives if start_date has arrived
  UPDATE public.drives
  SET status = 'active', updated_at = NOW()
  WHERE status = 'upcoming' 
    AND start_date IS NOT NULL 
    AND start_date <= NOW()
    AND (deleted_at IS NULL);

  -- 2. Auto-close active drives if application deadline (end_date) has passed
  UPDATE public.drives
  SET status = 'completed', updated_at = NOW()
  WHERE status IN ('active', 'open', 'ongoing', 'upcoming')
    AND end_date IS NOT NULL 
    AND end_date <= NOW()
    AND (deleted_at IS NULL);

  -- 3. Auto-delete drives 1 week (7 days) after deadline has passed
  UPDATE public.drives
  SET deleted_at = NOW(),
      status = 'cancelled',
      updated_at = NOW()
  WHERE deleted_at IS NULL
    AND end_date IS NOT NULL
    AND end_date + INTERVAL '7 days' <= NOW();
END;
$body$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution permission to authenticated users and service_role
GRANT EXECUTE ON FUNCTION public.auto_update_drive_statuses() TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_update_drive_statuses() TO anon;
GRANT EXECUTE ON FUNCTION public.auto_update_drive_statuses() TO service_role;
