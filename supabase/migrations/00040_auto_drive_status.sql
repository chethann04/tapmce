-- =============================================================
-- MIGRATION 00040: Auto Update Drive Statuses
-- =============================================================

CREATE OR REPLACE FUNCTION public.auto_update_drive_statuses()
RETURNS void AS $body$
BEGIN
  -- 1. Update upcoming drives to active if start_date has arrived
  UPDATE public.drives
  SET status = 'active', updated_at = NOW()
  WHERE status = 'upcoming' 
    AND start_date IS NOT NULL 
    AND start_date <= NOW();

  -- 2. Update active drives to completed if end_date has passed
  UPDATE public.drives
  SET status = 'completed', updated_at = NOW()
  WHERE status = 'active' 
    AND end_date IS NOT NULL 
    AND end_date <= NOW();
END;
$body$ LANGUAGE plpgsql SECURITY DEFINER;
