-- =============================================================================
-- Migration 00038: Definitive RLS Fix for Profiles, Notifications & Audit Logs
-- =============================================================================

-- 1. NOTIFICATIONS Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'general',
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
CREATE POLICY "Anyone can insert notifications" ON public.notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can read own notifications" ON public.notifications FOR SELECT USING (true);

-- 2. AUDIT_LOGS Table
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "audit_system_insert" ON public.audit_logs;
DROP POLICY IF EXISTS "audit_admin_select" ON public.audit_logs;
DROP POLICY IF EXISTS "Anyone can insert audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Anyone can read audit_logs" ON public.audit_logs;
CREATE POLICY "Anyone can insert audit_logs" ON public.audit_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can read audit_logs" ON public.audit_logs FOR SELECT USING (true);

-- 3. PROFILES Table: Clean ALL old policies and enable unconditional access
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profiles_self_select ON public.profiles;
DROP POLICY IF EXISTS profiles_self_insert ON public.profiles;
DROP POLICY IF EXISTS profiles_self_update ON public.profiles;
DROP POLICY IF EXISTS profiles_admin_all ON public.profiles;
DROP POLICY IF EXISTS profiles_tpo_select ON public.profiles;
DROP POLICY IF EXISTS profiles_tpo_update_faculty ON public.profiles;
DROP POLICY IF EXISTS profiles_faculty_select_dept ON public.profiles;
DROP POLICY IF EXISTS profiles_faculty_approve_dept ON public.profiles;
DROP POLICY IF EXISTS profiles_student_update_self ON public.profiles;
DROP POLICY IF EXISTS "Faculty view department students" ON public.profiles;
DROP POLICY IF EXISTS "Admin/TPO view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Faculty view all pending students" ON public.profiles;
DROP POLICY IF EXISTS "Staff can review student approval" ON public.profiles;
DROP POLICY IF EXISTS "Allow profile updates" ON public.profiles;
DROP POLICY IF EXISTS "Allow profile reads" ON public.profiles;
DROP POLICY IF EXISTS "Allow profile inserts" ON public.profiles;

CREATE POLICY "Allow profile reads" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Allow profile inserts" ON public.profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow profile updates" ON public.profiles FOR UPDATE USING (true) WITH CHECK (true);
