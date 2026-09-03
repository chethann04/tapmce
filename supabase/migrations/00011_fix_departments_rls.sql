-- ============================================================
-- Migration 00011: Fix departments RLS policies
-- ============================================================
-- The original migration 00007 used auth.role() = 'authenticated'
-- which may not resolve correctly in some Supabase configurations.
-- Replace with auth.uid() IS NOT NULL — the standard, reliable
-- pattern used throughout the codebase.
-- ============================================================

-- Drop the old policies
DROP POLICY IF EXISTS "Authenticated users can read departments" ON public.departments;
DROP POLICY IF EXISTS "Admin can manage departments" ON public.departments;

-- Recreate with auth.uid() — works for all authenticated users
CREATE POLICY "Authenticated users can read departments"
  ON public.departments FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Admin management policy (unchanged logic, just re-declared for clarity)
CREATE POLICY "Admin can manage departments"
  ON public.departments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
