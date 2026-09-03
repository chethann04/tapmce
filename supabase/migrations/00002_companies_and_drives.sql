-- ==========================================
-- PLACEMENT CONNECT: COMPANIES & DRIVES SCHEMA
-- ==========================================

-- 1. Companies Table
CREATE TABLE public.companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    industry TEXT,
    website TEXT,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Drives Table
CREATE TYPE drive_status AS ENUM ('upcoming', 'ongoing', 'completed', 'cancelled');

CREATE TABLE public.drives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    description TEXT,
    package_lpa DECIMAL(10, 2),
    eligibility_cgpa DECIMAL(3, 2) DEFAULT 0.00,
    eligibility_branches TEXT[] DEFAULT '{}', -- Empty array means all branches eligible
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    status drive_status NOT NULL DEFAULT 'upcoming',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_drives_company_id ON public.drives(company_id);
CREATE INDEX idx_drives_status ON public.drives(status);
CREATE INDEX idx_drives_start_date ON public.drives(start_date);

-- 3. Applications Table
CREATE TYPE application_status AS ENUM ('applied', 'shortlisted', 'rejected', 'selected', 'not_selected');

CREATE TABLE public.applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    drive_id UUID NOT NULL REFERENCES public.drives(id) ON DELETE CASCADE,
    status application_status NOT NULL DEFAULT 'applied',
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Prevent a student from applying to the same drive twice
    UNIQUE(student_id, drive_id) 
);

-- Indexes for applications
CREATE INDEX idx_applications_student_id ON public.applications(student_id);
CREATE INDEX idx_applications_drive_id ON public.applications(drive_id);

-- 4. Auto-update timestamps trigger (Reusable for these tables)
CREATE OR REPLACE FUNCTION public.update_modified_column()
RETURNS TRIGGER AS $$ BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
 $$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_companies_updated_at BEFORE UPDATE ON public.companies
    FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();

CREATE TRIGGER trigger_drives_updated_at BEFORE UPDATE ON public.drives
    FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();

CREATE TRIGGER trigger_applications_updated_at BEFORE UPDATE ON public.applications
    FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drives ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;


-- 6. RLS Policies: COMPANIES
-- All authenticated users can view companies
CREATE POLICY "Authenticated users can view companies" ON public.companies
    FOR SELECT USING (auth.role() = 'authenticated');

-- Only Admin/TPO can manage companies
CREATE POLICY "Admin/TPO can insert companies" ON public.companies
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
    );

CREATE POLICY "Admin/TPO can update companies" ON public.companies
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
    );

CREATE POLICY "Admin/TPO can delete companies" ON public.companies
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
    );


-- 7. RLS Policies: DRIVES
-- All authenticated users can view drives
CREATE POLICY "Authenticated users can view drives" ON public.drives
    FOR SELECT USING (auth.role() = 'authenticated');

-- Only Admin/TPO can manage drives
CREATE POLICY "Admin/TPO can insert drives" ON public.drives
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
    );

CREATE POLICY "Admin/TPO can update drives" ON public.drives
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
    );

CREATE POLICY "Admin/TPO can delete drives" ON public.drives
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
    );


-- 8. RLS Policies: APPLICATIONS
-- Students can view their own applications
CREATE POLICY "Students view own applications" ON public.applications
    FOR SELECT USING (auth.uid() = student_id);

-- Admin/TPO can view all applications
CREATE POLICY "Admin/TPO view all applications" ON public.applications
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
    );

-- Students can insert their own applications
CREATE POLICY "Students insert own applications" ON public.applications
    FOR INSERT WITH CHECK (auth.uid() = student_id);

-- Only Admin/TPO can update application statuses (e.g., shortlisting)
-- Note: Students should NOT be able to update their own application status.
CREATE POLICY "Admin/TPO update applications" ON public.applications
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'tpo'))
    );