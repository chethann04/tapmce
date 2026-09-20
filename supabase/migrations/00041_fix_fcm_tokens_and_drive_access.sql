-- =============================================================================
-- Migration 00041: Fix FCM Tokens, Notification Idempotency, and Drive Access
-- =============================================================================

-- 1. FCM TOKENS TABLE FIX
-- Ensure updated_at column exists so Flutter client upsert succeeds
ALTER TABLE public.fcm_tokens ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Enable RLS and add SELECT policy for token owners
ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own token" ON public.fcm_tokens;
CREATE POLICY "Users can view own token" ON public.fcm_tokens
  FOR SELECT USING (auth.uid() = user_id);

-- Ensure users can insert/update/delete their own tokens
DROP POLICY IF EXISTS "Users can insert own token" ON public.fcm_tokens;
CREATE POLICY "Users can insert own token" ON public.fcm_tokens
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own token" ON public.fcm_tokens;
CREATE POLICY "Users can update own token" ON public.fcm_tokens
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own token" ON public.fcm_tokens;
CREATE POLICY "Users can delete own token" ON public.fcm_tokens
  FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin/TPO view all tokens" ON public.fcm_tokens;
CREATE POLICY "Admin/TPO view all tokens" ON public.fcm_tokens
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
  );


-- 2. DRIVE STATUS ENUM ENHANCEMENT
-- Add 'active' value to drive_status if it is not already defined
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum 
    WHERE enumlabel = 'active' 
      AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'drive_status')
  ) THEN
    ALTER TYPE drive_status ADD VALUE 'active';
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;


-- 3. NOTIFICATIONS TABLE & IDEMPOTENCY
-- Add idempotency_key to prevent duplicate in-app notifications
ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
DROP INDEX IF EXISTS public.idx_notifications_idempotency;
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_idempotency 
  ON public.notifications(user_id, idempotency_key);

-- Fix RLS policies on notifications to ensure student privacy & staff access
DROP POLICY IF EXISTS "Anyone can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
DROP POLICY IF EXISTS notifications_student_select ON public.notifications;
DROP POLICY IF EXISTS notifications_tpo_insert ON public.notifications;
DROP POLICY IF EXISTS notifications_student_update ON public.notifications;
DROP POLICY IF EXISTS "Staff view all notifications" ON public.notifications;
DROP POLICY IF EXISTS "Authorized insert notifications" ON public.notifications;

CREATE POLICY "Users can read own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Staff view all notifications" ON public.notifications
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
  );

CREATE POLICY "Authorized insert notifications" ON public.notifications
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
    OR auth.uid() = user_id
  );

CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- 4. UPDATE NOTIFY TRIGGER ON NEW DRIVE (IDEMPOTENT)
CREATE OR REPLACE FUNCTION public.notify_students_on_new_drive()
RETURNS TRIGGER AS $$
DECLARE
  v_company_name text;
  v_title text;
  v_body text;
  v_idempotency_key text;
BEGIN
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
  v_idempotency_key := 'drive:' || NEW.id || ':created';

  -- Insert in-app notification rows for all approved students with idempotency key
  INSERT INTO public.notifications (user_id, title, body, type, drive_id, read, idempotency_key, created_at)
  SELECT 
    id AS user_id,
    v_title,
    v_body,
    'info',
    NEW.id,
    false,
    v_idempotency_key,
    NOW()
  FROM public.profiles
  WHERE role = 'student' AND approval_status = 'approved'
  ON CONFLICT (user_id, idempotency_key) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 5. BACKEND ENFORCEMENT: ONLY ACTIVE DRIVES CAN BE APPLIED TO
CREATE OR REPLACE FUNCTION public.check_drive_active_before_apply()
RETURNS TRIGGER AS $$
DECLARE
  v_drive_status text;
  v_end_date timestamptz;
BEGIN
  SELECT status::text, end_date INTO v_drive_status, v_end_date
  FROM public.drives
  WHERE id = NEW.drive_id;

  IF v_drive_status IS NULL THEN
    RAISE EXCEPTION 'Placement drive not found.';
  END IF;

  IF v_drive_status NOT IN ('active', 'open', 'ongoing') THEN
    RAISE EXCEPTION 'Applications are only allowed for active placement drives. Current status is %', v_drive_status;
  END IF;

  IF v_end_date IS NOT NULL AND v_end_date < NOW() THEN
    RAISE EXCEPTION 'The application deadline for this drive has passed.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_check_drive_active_before_apply ON public.applications;
CREATE TRIGGER trigger_check_drive_active_before_apply
  BEFORE INSERT ON public.applications
  FOR EACH ROW
  EXECUTE FUNCTION public.check_drive_active_before_apply();

-- Strengthen RLS policy on applications table
DROP POLICY IF EXISTS applications_student_insert ON public.applications;
CREATE POLICY applications_student_insert ON public.applications
  FOR INSERT WITH CHECK (
    student_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p 
      WHERE p.id = auth.uid() 
        AND p.approval_status = 'approved'
    )
    AND EXISTS (
      SELECT 1 FROM public.drives d
      WHERE d.id = drive_id
        AND d.status::text IN ('active', 'open', 'ongoing')
        AND (d.end_date IS NULL OR d.end_date > NOW())
    )
  );

-- Ensure unique constraint on (student_id, drive_id)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'applications_student_id_drive_id_key' 
       OR conname = 'applications_drive_id_student_id_key'
  ) THEN
    ALTER TABLE public.applications ADD CONSTRAINT applications_student_id_drive_id_key UNIQUE (student_id, drive_id);
  END IF;
EXCEPTION
  WHEN duplicate_table THEN NULL;
  WHEN others THEN NULL;
END $$;
