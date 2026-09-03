-- =============================================================
-- MIGRATION 00018: Create system_settings table and RLS policies
-- =============================================================

CREATE TABLE IF NOT EXISTS public.system_settings (
  id text PRIMARY KEY DEFAULT 'global_config',
  active_academic_year text NOT NULL DEFAULT '2025-26',
  graduating_batch text NOT NULL DEFAULT '2026',
  allow_multiple_offers boolean NOT NULL DEFAULT false,
  require_faculty_approval boolean NOT NULL DEFAULT true,
  consent_form_mandatory boolean NOT NULL DEFAULT true,
  auto_notify_students boolean NOT NULL DEFAULT true,
  default_cgpa numeric NOT NULL DEFAULT 7.0,
  max_backlogs int NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.profiles(id)
);

-- Insert default single global configuration row if missing
INSERT INTO public.system_settings (id)
VALUES ('global_config')
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- Allow read access to authenticated users
DROP POLICY IF EXISTS system_settings_read_authenticated ON public.system_settings;
CREATE POLICY system_settings_read_authenticated ON public.system_settings
  FOR SELECT TO authenticated USING (true);

-- Allow full update access to Admin and TPO roles
DROP POLICY IF EXISTS system_settings_write_admin ON public.system_settings;
CREATE POLICY system_settings_write_admin ON public.system_settings
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('admin', 'tpo')
    )
  );
