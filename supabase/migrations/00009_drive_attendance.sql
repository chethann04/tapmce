-- ============================================================
-- Migration 00009: Drive Attendance & QR Code Scanning
-- ============================================================
-- Tracks student attendance when scanning drive QR codes.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.drive_attendance (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drive_id     uuid NOT NULL REFERENCES public.drives(id) ON DELETE CASCADE,
  student_id   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  scanned_at   timestamptz NOT NULL DEFAULT now(),
  status       text NOT NULL DEFAULT 'present',
  CONSTRAINT drive_student_unique UNIQUE (drive_id, student_id)
);

-- Index for fast queries
CREATE INDEX IF NOT EXISTS idx_drive_attendance_drive_id ON public.drive_attendance(drive_id);
CREATE INDEX IF NOT EXISTS idx_drive_attendance_student_id ON public.drive_attendance(student_id);

-- RLS Security Policies
ALTER TABLE public.drive_attendance ENABLE ROW LEVEL SECURITY;

-- Students can insert their own attendance for active drives
CREATE POLICY "Students can record attendance"
  ON public.drive_attendance FOR INSERT
  WITH CHECK (
    auth.uid() = student_id
  );

-- Students can read their own attendance records
CREATE POLICY "Students can view own attendance"
  ON public.drive_attendance FOR SELECT
  USING (
    auth.uid() = student_id
  );

-- Admin, TPO, and Faculty can view & manage all attendance records
CREATE POLICY "Staff can manage drive attendance"
  ON public.drive_attendance FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin', 'tpo', 'faculty_coordinator', 'faculty')
    )
  );
