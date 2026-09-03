-- =============================================================
-- MIGRATION 00017: Create email_logs table for audit logging
-- =============================================================

CREATE TABLE IF NOT EXISTS public.email_logs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient    TEXT NOT NULL,
  subject      TEXT NOT NULL,
  email_type   TEXT NOT NULL,
  status       TEXT NOT NULL CHECK (status IN ('sent', 'failed', 'retried')),
  error_message TEXT,
  sent_at      TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL
);

-- Index for fast lookup and reporting
CREATE INDEX IF NOT EXISTS idx_email_logs_recipient ON public.email_logs(recipient);
CREATE INDEX IF NOT EXISTS idx_email_logs_email_type ON public.email_logs(email_type);
CREATE INDEX IF NOT EXISTS idx_email_logs_status ON public.email_logs(status);
CREATE INDEX IF NOT EXISTS idx_email_logs_created_at ON public.email_logs(created_at);

-- Row Level Security
ALTER TABLE public.email_logs ENABLE ROW LEVEL SECURITY;

-- Staff (Admin, TPO, Faculty) can view all email logs
CREATE POLICY "Staff can view email logs" ON public.email_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'tpo', 'faculty_coordinator', 'faculty')
    )
  );

-- Authenticated & Service Role can insert email logs
CREATE POLICY "Authenticated users can insert email logs" ON public.email_logs
  FOR INSERT WITH CHECK (auth.role() IN ('authenticated', 'service_role'));
