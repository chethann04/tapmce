-- =====================================================================
-- PLACEMENT CONNECT — SUPABASE SCHEMA (SAFE MASTER MIGRATION)
-- Roles: admin, tpo, faculty_coordinator, student
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. ENUMS & EXTENSIONS (Safe Alterations for Existing Postgres Types)
-- ---------------------------------------------------------------------
create extension if not exists "uuid-ossp";

-- Safe creation of user_role enum
do $$ begin
  create type user_role as enum ('admin', 'tpo', 'faculty_coordinator', 'faculty', 'student');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type approval_status as enum ('pending', 'approved', 'rejected');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type drive_status as enum ('draft', 'open', 'closed', 'completed');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type application_status as enum ('applied', 'shortlisted', 'interview', 'rejected', 'selected');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type consent_status as enum ('not_set', 'opted_in', 'opted_out');
exception
  when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------
-- 1. PROFILES (Base Table + Safe Column Alterations for Existing DBs)
-- ---------------------------------------------------------------------
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null default 'student',
  name text not null default 'User',
  email text not null unique,
  phone text,
  usn text unique,
  department text,
  batch text,
  tenth_percent numeric(5,2),
  twelfth_or_diploma_percent numeric(5,2),
  cgpa_semesterwise jsonb,
  active_backlogs int default 0,
  resume_url text,
  photo_url text,
  id_proof_url text,
  skills jsonb default '[]',
  certifications jsonb default '[]',
  projects jsonb default '[]',
  achievements jsonb default '[]',
  consent_status consent_status default 'not_set',
  consent_reason text,
  approval_status approval_status not null default 'pending',
  approved_by uuid references profiles(id),
  approved_at timestamptz,
  rejection_reason text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure columns exist if table was already created in earlier schema
alter table profiles add column if not exists name text not null default 'User';
alter table profiles add column if not exists phone text;
alter table profiles add column if not exists usn text;
alter table profiles add column if not exists department text;
alter table profiles add column if not exists batch text;
alter table profiles add column if not exists tenth_percent numeric(5,2);
alter table profiles add column if not exists twelfth_or_diploma_percent numeric(5,2);
alter table profiles add column if not exists cgpa_semesterwise jsonb;
alter table profiles add column if not exists active_backlogs int default 0;
alter table profiles add column if not exists resume_url text;
alter table profiles add column if not exists photo_url text;
alter table profiles add column if not exists id_proof_url text;
alter table profiles add column if not exists skills jsonb default '[]';
alter table profiles add column if not exists certifications jsonb default '[]';
alter table profiles add column if not exists projects jsonb default '[]';
alter table profiles add column if not exists achievements jsonb default '[]';
alter table profiles add column if not exists consent_status consent_status default 'not_set';
alter table profiles add column if not exists consent_reason text;
alter table profiles add column if not exists approval_status approval_status not null default 'pending';
alter table profiles add column if not exists approved_by uuid references profiles(id);
alter table profiles add column if not exists approved_at timestamptz;
alter table profiles add column if not exists rejection_reason text;
alter table profiles add column if not exists created_by uuid references profiles(id);

create index if not exists idx_profiles_role on profiles(role);
create index if not exists idx_profiles_department on profiles(department);
create index if not exists idx_profiles_approval_status on profiles(approval_status);

-- ---------------------------------------------------------------------
-- 2. FACULTY COORDINATORS — 1 coordinator per department, appointed by TPO
-- ---------------------------------------------------------------------
create table if not exists faculty_coordinators (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references profiles(id) on delete cascade,
  department text not null unique,
  appointed_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. TPO APPOINTMENTS — Admin appoints TPOs
-- ---------------------------------------------------------------------
create table if not exists tpo_appointments (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references profiles(id) on delete cascade,
  appointed_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 4. ACADEMIC CYCLES (Admin setup)
-- ---------------------------------------------------------------------
create table if not exists academic_cycles (
  id uuid primary key default gen_random_uuid(),
  academic_year text not null,
  eligible_batch text not null,
  branches jsonb not null default '[]',
  is_active boolean default true,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5. COMPANIES (TPO onboards)
-- ---------------------------------------------------------------------
create table if not exists companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  logo_url text,
  industry text,
  hr_contact_name text,
  hr_contact_email text,
  hr_contact_phone text,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 6. DRIVES (TPO creates & owns lifecycle end-to-end)
-- ---------------------------------------------------------------------
create table if not exists drives (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  academic_cycle_id uuid references academic_cycles(id),
  role_title text not null default 'Job Role',
  ctc_or_stipend text,
  job_description text,
  eligibility_branches jsonb not null default '[]',
  cgpa_cutoff numeric(3,2),
  backlog_limit int default 0,
  rounds_count int not null default 1,
  application_deadline timestamptz,
  status drive_status not null default 'draft',
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table drives add column if not exists role_title text not null default 'Job Role';

create index if not exists idx_drives_status on drives(status);
create index if not exists idx_drives_company on drives(company_id);

-- ---------------------------------------------------------------------
-- 7. DRIVE ELIGIBILITY EXCEPTIONS
-- ---------------------------------------------------------------------
create table if not exists drive_eligibility_exceptions (
  id uuid primary key default gen_random_uuid(),
  drive_id uuid not null references drives(id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  exception_type text not null check (exception_type in ('added','removed')),
  reason text not null,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  unique(drive_id, student_id)
);

-- ---------------------------------------------------------------------
-- 8. DRIVE ROUNDS
-- ---------------------------------------------------------------------
create table if not exists drive_rounds (
  id uuid primary key default gen_random_uuid(),
  drive_id uuid not null references drives(id) on delete cascade,
  round_number int not null,
  round_name text not null,
  round_date date,
  round_time time,
  venue_or_link text,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now(),
  unique(drive_id, round_number)
);

-- ---------------------------------------------------------------------
-- 9. APPLICATIONS
-- ---------------------------------------------------------------------
create table if not exists applications (
  id uuid primary key default gen_random_uuid(),
  drive_id uuid not null references drives(id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  status application_status not null default 'applied',
  current_round int default 0,
  resume_version_url text,
  why_this_role text,
  applied_at timestamptz not null default now(),
  updated_by uuid references profiles(id),
  updated_at timestamptz not null default now(),
  unique(drive_id, student_id)
);

create index if not exists idx_applications_student on applications(student_id);
create index if not exists idx_applications_drive on applications(drive_id);
create index if not exists idx_applications_status on applications(status);

-- ---------------------------------------------------------------------
-- 10. APPLICATION ROUND HISTORY
-- ---------------------------------------------------------------------
create table if not exists application_round_status (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references applications(id) on delete cascade,
  round_id uuid not null references drive_rounds(id) on delete cascade,
  attended boolean default false,
  result text check (result in ('pending','cleared','rejected')) default 'pending',
  updated_by uuid references profiles(id),
  updated_at timestamptz not null default now(),
  unique(application_id, round_id)
);

-- ---------------------------------------------------------------------
-- 11. INTERVIEW FEEDBACK
-- ---------------------------------------------------------------------
create table if not exists interview_feedback (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references applications(id) on delete cascade,
  round_id uuid not null references drive_rounds(id) on delete cascade,
  faculty_id uuid not null references profiles(id),
  rating int check (rating between 1 and 5),
  remarks text,
  recommend boolean,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 12. OFFERS
-- ---------------------------------------------------------------------
create table if not exists offers (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null unique references applications(id) on delete cascade,
  ctc_offered text,
  offer_letter_url text,
  joining_date date,
  uploaded_by uuid not null references profiles(id),
  decision text check (decision in ('pending','accepted','declined')) default 'pending',
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 13. NOTICES
-- ---------------------------------------------------------------------
create table if not exists notices (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  target_audience text not null default 'all',
  pin boolean default false,
  expires_at timestamptz,
  created_by uuid not null references profiles(id),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 14. QUERIES / GRIEVANCES
-- ---------------------------------------------------------------------
create table if not exists student_queries (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  category text not null,
  message text not null,
  attachment_url text,
  status text not null default 'open' check (status in ('open','resolved')),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 15. AUDIT LOG
-- ---------------------------------------------------------------------
create table if not exists audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references profiles(id),
  action text not null,
  target_table text,
  target_id uuid,
  details jsonb,
  created_at timestamptz not null default now()
);

-- =====================================================================
-- ROW LEVEL SECURITY & POLICIES
-- =====================================================================

alter table profiles enable row level security;
alter table faculty_coordinators enable row level security;
alter table tpo_appointments enable row level security;
alter table academic_cycles enable row level security;
alter table companies enable row level security;
alter table drives enable row level security;
alter table drive_eligibility_exceptions enable row level security;
alter table drive_rounds enable row level security;
alter table applications enable row level security;
alter table application_round_status enable row level security;
alter table interview_feedback enable row level security;
alter table offers enable row level security;
alter table notices enable row level security;
alter table student_queries enable row level security;
alter table audit_logs enable row level security;

-- Helper functions (SECURITY DEFINER to avoid infinite RLS recursion on profiles)
create or replace function auth_role() returns user_role
language sql stable security definer as $$
  select role from profiles where id = auth.uid();
$$;

create or replace function auth_department() returns text
language sql stable security definer as $$
  select department from profiles where id = auth.uid();
$$;

-- PROFILES policies
drop policy if exists profiles_self_select on profiles;
create policy profiles_self_select on profiles for select using (id = auth.uid());

drop policy if exists profiles_admin_all on profiles;
create policy profiles_admin_all on profiles for all using (auth_role() = 'admin');

drop policy if exists profiles_tpo_select on profiles;
create policy profiles_tpo_select on profiles for select using (auth_role() = 'tpo');

drop policy if exists profiles_tpo_update_faculty on profiles;
create policy profiles_tpo_update_faculty on profiles for update using (auth_role() = 'tpo' and role in ('faculty_coordinator','faculty','student'));

drop policy if exists profiles_faculty_select_dept on profiles;
create policy profiles_faculty_select_dept on profiles for select using (
  auth_role() in ('faculty_coordinator','faculty') and role = 'student' and department = auth_department()
);

drop policy if exists profiles_faculty_approve_dept on profiles;
create policy profiles_faculty_approve_dept on profiles for update using (
  auth_role() in ('faculty_coordinator','faculty') and role = 'student' and department = auth_department()
);

drop policy if exists profiles_student_update_self on profiles;
create policy profiles_student_update_self on profiles for update using (id = auth.uid() and auth_role() = 'student');

-- FACULTY_COORDINATORS policies
drop policy if exists fc_tpo_all on faculty_coordinators;
create policy fc_tpo_all on faculty_coordinators for all using (auth_role() = 'tpo');

drop policy if exists fc_admin_select on faculty_coordinators;
create policy fc_admin_select on faculty_coordinators for select using (auth_role() = 'admin');

drop policy if exists fc_self_select on faculty_coordinators;
create policy fc_self_select on faculty_coordinators for select using (profile_id = auth.uid());

-- TPO_APPOINTMENTS policies
drop policy if exists tpo_appt_admin_all on tpo_appointments;
create policy tpo_appt_admin_all on tpo_appointments for all using (auth_role() = 'admin');

drop policy if exists tpo_appt_self_select on tpo_appointments;
create policy tpo_appt_self_select on tpo_appointments for select using (profile_id = auth.uid());

-- ACADEMIC_CYCLES policies
drop policy if exists cycles_admin_all on academic_cycles;
create policy cycles_admin_all on academic_cycles for all using (auth_role() = 'admin');

drop policy if exists cycles_read_all on academic_cycles;
create policy cycles_read_all on academic_cycles for select using (true);

-- COMPANIES / DRIVES / ROUNDS / ELIGIBILITY policies
drop policy if exists companies_tpo_all on companies;
create policy companies_tpo_all on companies for all using (auth_role() = 'tpo');

drop policy if exists companies_read_all on companies;
create policy companies_read_all on companies for select using (true);

drop policy if exists drives_tpo_all on drives;
create policy drives_tpo_all on drives for all using (auth_role() = 'tpo');

drop policy if exists drives_read_approved_students on drives;
create policy drives_read_approved_students on drives for select using (
  auth_role() in ('admin','faculty_coordinator','faculty')
  or (auth_role() = 'student' and exists (
    select 1 from profiles p where p.id = auth.uid() and p.approval_status = 'approved'
  ))
);

drop policy if exists exceptions_tpo_all on drive_eligibility_exceptions;
create policy exceptions_tpo_all on drive_eligibility_exceptions for all using (auth_role() = 'tpo');

drop policy if exists rounds_tpo_all on drive_rounds;
create policy rounds_tpo_all on drive_rounds for all using (auth_role() = 'tpo');

drop policy if exists rounds_read_all on drive_rounds;
create policy rounds_read_all on drive_rounds for select using (true);

-- APPLICATIONS policies
drop policy if exists applications_student_select on applications;
create policy applications_student_select on applications for select using (student_id = auth.uid());

drop policy if exists applications_student_insert on applications;
create policy applications_student_insert on applications for insert with check (
  student_id = auth.uid()
  and exists (
    select 1 from profiles p 
    where p.id = auth.uid() 
      and p.approval_status = 'approved'
      and p.consent_status = 'opted_in'
  )
);

drop policy if exists applications_tpo_all on applications;
create policy applications_tpo_all on applications for all using (auth_role() = 'tpo');

drop policy if exists applications_faculty_select_dept on applications;
create policy applications_faculty_select_dept on applications for select using (
  auth_role() in ('faculty_coordinator','faculty')
  and exists (
    select 1 from profiles p
    where p.id = applications.student_id and p.department = auth_department()
  )
);

drop policy if exists applications_admin_select on applications;
create policy applications_admin_select on applications for select using (auth_role() = 'admin');

-- APPLICATION_ROUND_STATUS policies
drop policy if exists ars_tpo_all on application_round_status;
create policy ars_tpo_all on application_round_status for all using (auth_role() = 'tpo');

drop policy if exists ars_student_select on application_round_status;
create policy ars_student_select on application_round_status for select using (exists (
  select 1 from applications a where a.id = application_round_status.application_id and a.student_id = auth.uid()
));

drop policy if exists ars_faculty_select_dept on application_round_status;
create policy ars_faculty_select_dept on application_round_status for select using (
  auth_role() in ('faculty_coordinator','faculty')
  and exists (
    select 1 from applications a
    join profiles p on p.id = a.student_id
    where a.id = application_round_status.application_id and p.department = auth_department()
  )
);

-- INTERVIEW_FEEDBACK policies
drop policy if exists feedback_faculty_own on interview_feedback;
create policy feedback_faculty_own on interview_feedback for all using (faculty_id = auth.uid());

drop policy if exists feedback_tpo_select on interview_feedback;
create policy feedback_tpo_select on interview_feedback for select using (auth_role() = 'tpo');

-- OFFERS policies
drop policy if exists offers_tpo_all on offers;
create policy offers_tpo_all on offers for all using (auth_role() = 'tpo');

drop policy if exists offers_student_select on offers;
create policy offers_student_select on offers for select using (exists (
  select 1 from applications a where a.id = offers.application_id and a.student_id = auth.uid()
));

drop policy if exists offers_student_decision on offers;
create policy offers_student_decision on offers for update using (exists (
  select 1 from applications a where a.id = offers.application_id and a.student_id = auth.uid()
));

drop policy if exists offers_faculty_select_dept on offers;
create policy offers_faculty_select_dept on offers for select using (
  auth_role() in ('faculty_coordinator','faculty')
  and exists (
    select 1 from applications a
    join profiles p on p.id = a.student_id
    where a.id = offers.application_id and p.department = auth_department()
  )
);

drop policy if exists offers_admin_select on offers;
create policy offers_admin_select on offers for select using (auth_role() = 'admin');

-- NOTICES policies
drop policy if exists notices_tpo_admin_all on notices;
create policy notices_tpo_admin_all on notices for all using (auth_role() in ('tpo','admin'));

drop policy if exists notices_read_all on notices;
create policy notices_read_all on notices for select using (true);

-- STUDENT_QUERIES policies
drop policy if exists queries_student_own on student_queries;
create policy queries_student_own on student_queries for all using (student_id = auth.uid());

drop policy if exists queries_tpo_admin_select on student_queries;
create policy queries_tpo_admin_select on student_queries for select using (auth_role() in ('tpo','admin'));

-- AUDIT_LOGS policies
drop policy if exists audit_admin_select on audit_logs;
create policy audit_admin_select on audit_logs for select using (auth_role() = 'admin');

drop policy if exists audit_system_insert on audit_logs;
create policy audit_system_insert on audit_logs for insert with check (true);

-- =====================================================================
-- VIEWS for stats
-- =====================================================================

create or replace view department_placement_stats as
select
  p.department,
  count(distinct p.id) filter (where p.role = 'student') as total_students,
  count(distinct a.student_id) filter (where a.status = 'selected') as total_placed,
  count(distinct a.student_id) as total_attended_any_drive
from profiles p
left join applications a on a.student_id = p.id
where p.role = 'student'
group by p.department;

alter view department_placement_stats set (security_invoker = true);

create or replace view drive_stats as
select
  d.id as drive_id,
  d.role_title,
  c.name as company_name,
  count(a.id) as total_applied,
  count(a.id) filter (where a.status = 'shortlisted') as total_shortlisted,
  count(a.id) filter (where a.status = 'selected') as total_selected
from drives d
join companies c on c.id = d.company_id
left join applications a on a.drive_id = d.id
group by d.id, d.role_title, c.name;

alter view drive_stats set (security_invoker = true);

-- =====================================================================
-- TRIGGERS
-- =====================================================================

create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated on profiles;
create trigger trg_profiles_updated before update on profiles for each row execute function set_updated_at();

drop trigger if exists trg_drives_updated on drives;
create trigger trg_drives_updated before update on drives for each row execute function set_updated_at();

drop trigger if exists trg_applications_updated on applications;
create trigger trg_applications_updated before update on applications for each row execute function set_updated_at();

create or replace function guard_student_self_update() returns trigger
language plpgsql as $$
begin
  if auth_role() = 'student' then
    new.role := old.role;
    new.approval_status := old.approval_status;
    new.approved_by := old.approved_by;
    new.approved_at := old.approved_at;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_student_self_update on profiles;
create trigger trg_guard_student_self_update before update on profiles for each row execute function guard_student_self_update();