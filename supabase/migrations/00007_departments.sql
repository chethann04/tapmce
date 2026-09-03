-- ============================================================
-- Migration 00007: Departments table with branch codes
-- ============================================================
-- Stores the official department list managed by the Admin.
-- branch_code maps to the USN segment used for auto-detection.
-- e.g., USN 4MC23IS021 → branch_code = 'IS'
-- ============================================================

CREATE TABLE IF NOT EXISTS public.departments (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name         text NOT NULL,
  branch_code  text NOT NULL,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT departments_branch_code_unique UNIQUE (branch_code)
);

-- Seed the four initial departments
INSERT INTO public.departments (name, branch_code) VALUES
  ('Information Science Engineering',      'IS'),
  ('Computer Science Engineering',         'CS'),
  ('Civil Engineering',                    'CV'),
  ('Electronics & Communication Engineering', 'EC')
ON CONFLICT (branch_code) DO NOTHING;

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read (needed during signup for USN lookup)
CREATE POLICY "Authenticated users can read departments"
  ON public.departments FOR SELECT
  USING (auth.role() = 'authenticated');

-- Only admin can insert/update/delete
CREATE POLICY "Admin can manage departments"
  ON public.departments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
