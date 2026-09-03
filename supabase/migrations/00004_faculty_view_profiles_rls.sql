-- ==========================================
-- FACULTY PROFILE VIEWING PERMISSIONS
-- ==========================================

-- Faculty can view profiles of students in their OWN department
drop policy if exists "Faculty view department students" on public.profiles;
CREATE POLICY "Faculty view department students" ON public.profiles
    FOR SELECT USING (
        auth_role() in ('faculty', 'faculty_coordinator')
        AND profiles.role = 'student'
        AND profiles.department = auth_department()
    );

-- Admin and TPO can view ALL profiles
drop policy if exists "Admin/TPO view all profiles" on public.profiles;
CREATE POLICY "Admin/TPO view all profiles" ON public.profiles
    FOR SELECT USING (
        auth_role() IN ('admin', 'tpo')
    );