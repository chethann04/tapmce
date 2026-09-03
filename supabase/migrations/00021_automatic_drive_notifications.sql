-- =============================================================
-- MIGRATION 00021: Automatic Database Trigger for Notifications
-- =============================================================

-- 1. Create a Database Function that inserts in-app notifications
--    for all approved students whenever a new drive is created
CREATE OR REPLACE FUNCTION public.notify_students_on_new_drive()
RETURNS TRIGGER AS $$
DECLARE
  v_company_name text;
  v_title text;
  v_body text;
BEGIN
  -- Fetch Company Name
  SELECT name INTO v_company_name
  FROM public.companies
  WHERE id = NEW.company_id;

  IF v_company_name IS NULL THEN
    v_company_name := 'Placement Drive';
  END IF;

  v_title := '🚀 New Placement Drive: ' || v_company_name;
  v_body := 'Role: ' || COALESCE(NEW.role_title, NEW.role, 'Job Role') || 
            COALESCE(' | CTC: ' || NEW.ctc_or_stipend, '') || 
            '. Apply before deadline!';

  -- Insert in-app notification rows for all approved students
  INSERT INTO public.notifications (user_id, title, body, type, drive_id, read, created_at)
  SELECT 
    id AS user_id,
    v_title,
    v_body,
    'info',
    NEW.id,
    false,
    NOW()
  FROM public.profiles
  WHERE role = 'student' AND approval_status = 'approved';

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Attach Database Trigger on drives table
DROP TRIGGER IF EXISTS trigger_notify_students_on_new_drive ON public.drives;

CREATE TRIGGER trigger_notify_students_on_new_drive
  AFTER INSERT ON public.drives
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_students_on_new_drive();
