# MASTER PROMPT — Placement Connect Implementation

Single, self-contained implementation brief for Placement Connect (Flutter + Riverpod + Supabase). Everything needed — schema, roles, workflow, business rules, scope — is inlined below. No external files required.

---

## 1. Role hierarchy (authoritative)

| Role | Appointed by | Appoints | Approves | Sees |
|---|---|---|---|---|
| Admin | — | TPO | — | NAAC/NBA institution-wide reports |
| TPO | Admin | Faculty Coordinators (dept-wise) | — | All drives, all departments' stats, attendance |
| Faculty Coordinator | TPO (exactly 1 per department) | — | Students, on first login (dept-scoped) | Own department's placement history + drive attendance |
| Student | — (self-registers) | — | — | Own applications, eligible drives |

- **Admin** appoints TPO only. Does not manage Faculty or students directly. Only other function: NAAC/NBA institution-wide reporting.
- **TPO** appoints Faculty Coordinators, exactly one per department. Owns the entire drive lifecycle: create drive → schedule rounds → update every student's status per round → upload offers → close drive. Sees all departments' stats and attendance.
- **Faculty Coordinator** approves students on first successful login, scoped to their own department only. May optionally submit interview feedback if sitting on a panel — separate capability from the approval gate.
- **Student** self-registers, is blocked from applying to any drive until Faculty Coordinator approval, then opts in/out of placements, applies to eligible drives, tracks status, accepts/declines offers.

## 2. End-to-end workflow

1. **Admin** sets up the academic cycle (year, eligible batch, branches) and appoints TPO account(s).
2. **TPO** appoints one Faculty Coordinator per department.
3. **Student** registers and completes profile (academic records, resume, skills). Account starts `pending` — cannot apply to any drive yet.
4. **Faculty Coordinator** approves (or rejects, with reason) the student on first successful login. Until approved, student is blocked from applying — enforced at the database level, not just UI.
5. **Student** completes consent/opt-in form, or opts out with a reason. Opted-out students are excluded from all eligible-lists automatically.
6. **TPO** onboards a company and creates a drive — role, CTC, job description, eligibility criteria (branch, CGPA cutoff, backlog limit), rounds, deadline. Can manually add/remove eligibility exceptions with a reason.
7. **Student** views eligible drives and applies (only approved + opted-in + eligible students see a given drive).
8. **TPO** runs the drive end-to-end: schedules each round (test/GD/tech/HR — date, time, venue/link) and continuously updates each student's status per round (applied → shortlisted → interview → selected/rejected) until the drive closes.
9. **Faculty** (optional, if on an interview panel) submits round-level feedback — rating, remarks, recommend/don't recommend.
10. **TPO** uploads final offers (CTC offered, offer letter, joining date); **Student** accepts or declines.
11. **Tracking throughout**: TPO sees everything; Faculty Coordinator sees only their own department; Admin pulls NAAC/NBA institution-wide rollups.

## 3. Non-negotiable business rules

- A student with `approval_status != 'approved'` must be blocked from applying to drives — enforced at the RLS layer; UI must also disable the Apply action and show a clear "pending approval" state.
- Exactly one Faculty Coordinator per department — UI must check for an existing coordinator before appointing a new one and offer reassignment rather than allowing a duplicate.
- Opted-out students must never appear in any drive's eligible-list, TPO's applicant view, or Faculty's attendance stats.
- Faculty Coordinator data access is department-scoped everywhere — profiles, applications, round status, offers. Never expose cross-department data to Faculty; Admin owns cross-department reporting.
- TPO is the only role that can transition application status and round status. Faculty's interview feedback does not itself change application status — TPO reads feedback and makes the update.

## 4. Database schema (Supabase / Postgres)

### Enums
- `user_role`: admin, tpo, faculty_coordinator, student
- `approval_status`: pending, approved, rejected
- `drive_status`: draft, open, closed, completed
- `application_status`: applied, shortlisted, interview, rejected, selected
- `consent_status`: not_set, opted_in, opted_out

### Tables

**profiles** (id = auth.users id, base table for all roles)
- id (uuid, PK), role (user_role, default student), name, email (unique), phone
- Student-specific: usn (unique), department, batch, tenth_percent, twelfth_or_diploma_percent, cgpa_semesterwise (jsonb), active_backlogs (int), resume_url, photo_url, id_proof_url, skills (jsonb), certifications (jsonb), projects (jsonb), achievements (jsonb)
- consent_status, consent_reason
- approval_status (default pending), approved_by (uuid → profiles), approved_at, rejection_reason
- created_by (uuid → profiles), created_at, updated_at
- Indexes on role, department, approval_status

**faculty_coordinators**
- id (uuid, PK), profile_id (uuid, unique, → profiles), department (text, **unique**), appointed_by (uuid → profiles, must be tpo), created_at

**tpo_appointments**
- id (uuid, PK), profile_id (uuid, unique, → profiles), appointed_by (uuid → profiles, must be admin), created_at

**academic_cycles**
- id (uuid, PK), academic_year, eligible_batch, branches (jsonb array), is_active (bool), created_by (→ profiles), created_at

**companies**
- id (uuid, PK), name, logo_url, industry, hr_contact_name, hr_contact_email, hr_contact_phone, created_by (→ profiles), created_at

**drives**
- id (uuid, PK), company_id (→ companies), academic_cycle_id (→ academic_cycles), role_title, ctc_or_stipend, job_description
- eligibility_branches (jsonb array), cgpa_cutoff (numeric), backlog_limit (int, default 0), rounds_count (int), application_deadline (timestamptz)
- status (drive_status, default draft), created_by (→ profiles, tpo), updated_by, created_at, updated_at
- Indexes on status, company_id

**drive_eligibility_exceptions**
- id (uuid, PK), drive_id (→ drives), student_id (→ profiles), exception_type ('added'|'removed'), reason (required), created_by (→ profiles), created_at
- unique(drive_id, student_id)

**drive_rounds**
- id (uuid, PK), drive_id (→ drives), round_number (int), round_name (text — e.g. Test/GD/Tech Interview/HR Interview), round_date, round_time, venue_or_link, created_by (→ profiles), created_at
- unique(drive_id, round_number)

**applications**
- id (uuid, PK), drive_id (→ drives), student_id (→ profiles), status (application_status, default applied), current_round (int, default 0)
- resume_version_url, why_this_role, applied_at, updated_by (→ profiles, tpo), updated_at
- unique(drive_id, student_id); indexes on student_id, drive_id, status

**application_round_status**
- id (uuid, PK), application_id (→ applications), round_id (→ drive_rounds), attended (bool), result ('pending'|'cleared'|'rejected'), updated_by (→ profiles), updated_at
- unique(application_id, round_id)

**interview_feedback**
- id (uuid, PK), application_id (→ applications), round_id (→ drive_rounds), faculty_id (→ profiles), rating (1-5), remarks, recommend (bool), created_at

**offers**
- id (uuid, PK), application_id (→ applications, unique), ctc_offered, offer_letter_url, joining_date
- uploaded_by (→ profiles, tpo), decision ('pending'|'accepted'|'declined'), decided_at, created_at

**notices**
- id (uuid, PK), title, body, target_audience (default 'all' — or branch/batch code), pin (bool), expires_at, created_by (→ profiles), created_at

**student_queries**
- id (uuid, PK), student_id (→ profiles), category, message, attachment_url, status ('open'|'resolved', default open), created_at

**audit_logs**
- id (uuid, PK), actor_id (→ profiles), action, target_table, target_id, details (jsonb), created_at

### Views
- **department_placement_stats**: department, total_students, total_placed (status=selected), total_attended_any_drive — grouped by department. Built with `security_invoker = true` so RLS applies to the caller.
- **drive_stats**: drive_id, role_title, company_name, total_applied, total_shortlisted, total_selected — grouped by drive. Also `security_invoker = true`.

### RLS policy summary (all tables have RLS enabled)
- Helper functions: `auth_role()` (current user's role), `auth_department()` (current user's department), `is_coordinator_of(dept)`.
- **profiles**: self can read own row; admin full access; tpo can read all and update role/approval fields for faculty_coordinator/student rows; faculty_coordinator can read/update only student rows where `department = auth_department()`; student can update own row (role/approval fields locked by trigger — see below).
- **faculty_coordinators**: tpo full access; admin read; self read.
- **tpo_appointments**: admin full access; self read.
- **academic_cycles**: admin full access; everyone can read.
- **companies, drives, drive_rounds**: tpo full access; everyone can read (drives additionally require the reading student to be `approval_status = approved`).
- **drive_eligibility_exceptions**: tpo full access only.
- **applications**: student can select/insert own rows (insert requires `approval_status = approved`); tpo full access; faculty_coordinator can select rows where the student's department matches `auth_department()`; admin can select all.
- **application_round_status**: tpo full access; student can select own; faculty_coordinator can select dept-scoped.
- **interview_feedback**: faculty full access to own submitted rows; tpo can select.
- **offers**: tpo full access; student can select/update own (accept/decline); faculty_coordinator can select dept-scoped; admin can select.
- **notices**: tpo/admin full access; everyone can read.
- **student_queries**: student full access to own; tpo/admin can select.
- **audit_logs**: admin can select; inserts happen via triggers/service role.

### Triggers
- `set_updated_at`: refreshes `updated_at` on profiles, drives, applications before update.
- `guard_student_self_update`: when the acting role is `student`, forces `role`, `approval_status`, `approved_by`, `approved_at` to stay unchanged on their own profile update — prevents self-escalation even though students have an update policy on their own row.

## 5. Implementation scope for this pass

Build, in this order:

### A. Auth & profile bootstrap
- Sign up / login (Supabase Auth); role assigned at creation (default `student` for self-registration).
- Post-login routing: check `profiles.role` → route to correct module shell (Student / Faculty / TPO / Admin).
- Post-login gate for students: check `approval_status`; if `pending`, show a blocked/waiting screen (browse-only, no Apply actions) instead of the full student home.

### B. Admin module
- Appoint TPO: create `profiles` row (role=`tpo`) + `tpo_appointments` row.
- Academic cycle CRUD.
- NAAC/NBA report screen: query `department_placement_stats` and `drive_stats`, cross-department rollup, export (PDF/XLSX).

### C. TPO module
- Appoint Faculty Coordinator: create/update `faculty_coordinators` row scoped to a department (block duplicates).
- Companies CRUD.
- Drive creation + eligibility criteria + eligibility exceptions.
- Round scheduling.
- Applicant list per drive, with bulk/CSV shortlist upload updating `applications.status` and `application_round_status`.
- Offer upload.
- TPO dashboard: all-department stats via the two views (no department filter).

### D. Faculty Coordinator module
- Pending-approval queue: students in `auth_department()` with `approval_status = pending` → approve/reject with reason.
- Department placement history: `department_placement_stats` filtered to own department (RLS scopes this automatically).
- Drive attendance view for own department's students.
- Optional interview feedback form, only for rounds where faculty is listed as panel.

### E. Student module
- Profile setup (multi-step): academic details, resume/documents, skills & achievements.
- Consent/opt-in form.
- Eligible drives list (respecting approval + consent + eligibility criteria + exceptions).
- Apply form (blocked entirely if not approved).
- My Applications status tracker.
- Offer accept/decline.
- Grievance/query form, settings (password, notification prefs).

## 6. Deliverables expected from the coding session

For each module above:
- Riverpod providers (state + async notifiers) per feature.
- Repository layer wrapping Supabase client calls — one repository per table/domain (e.g. `ProfileRepository`, `DriveRepository`, `ApplicationRepository`, `FacultyApprovalRepository`), no raw Supabase calls inside widgets.
- Screens wired to these repositories/providers per the module breakdown above.

Focus on correct data flow, correct role gating, and correct RLS-respecting queries first — not UI polish/theming. Flag any feature requiring a capability outside the current schema (e.g. CSV bulk-upload parsing, PDF/XLSX export) so it can be scoped separately.

## 7. Open items to confirm before coding starts

- Target stack details: Flutter version, existing state-management conventions if any code already exists, whether Supabase client is already initialized elsewhere in the project.
- CSV/bulk-upload format for shortlist uploads (expected column names/structure).
- PDF/XLSX export library choice for Admin/TPO reports.
