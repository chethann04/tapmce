# Placement Connect — Project Progress & Pending Items Report

This document outlines the current state of **Placement Connect** (Flutter + Riverpod + Supabase), detailing what has been implemented and what remains pending according to the [Master Implementation Prompt](file:///e:/placement_connect/placement-connect-master-prompt.md).

---

## 📊 Summary of Project Status

| Module / Component | Status | Key Highlights |
| :--- | :---: | :--- |
| **Database & Supabase RLS** | 🟢 90% Complete | All core tables, enums, triggers, and RLS policies (00001-00006) defined. |
| **Auth & Routing** | 🟢 90% Complete | Login, Signup, OTP, Role-based routing, Direction A Glass/Glow Login screen, and Pending Approval Gate screen (`PendingApprovalScreen`) ready. |
| **Admin Module** | 🟡 85% Complete | TPO appointment screen (`TpoAppointmentScreen`), System Settings, Audit logs, and NAAC/NBA PDF/XLSX export screens ready. |
| **TPO Module** | 🟢 90% Complete | Demo data cleared, PostgREST query bug fixed, 3-step Drive Creation Wizard (`DriveCreationWizard`), Faculty appointment UI, Applicant list & CSV shortlist parser ready. |
| **Faculty Coordinator Module**| 🟡 85% Complete | Student approval queue (`StudentApprovalQueueScreen`), placement stats, continuous card polish, and attendance tracking screens ready. |
| **Student Module** | 🟢 90% Complete | Direction A Bento Grid dashboard, Profile setup wizard (`ProfileSetupScreen`), Consent form (`ConsentFormScreen`), Eligible Drives screen, Application form, and Floating Pill Bar ready. |
| **Offline Sync & Infrastructure** | 🟢 95% Complete | Drift local database queue, connectivity monitoring, realtime listeners, 22 unit tests, PDF/XLSX/CSV export packages, Direction A Theme polish ready. |

---

## 📑 Detailed Item Tracker

### 1. Auth & Onboarding Bootstrap
- [x] Supabase Auth integration (email/password & OTP verification).
- [x] Initial role assignment (`student` default on self-registration).
- [x] Post-login role-based routing (Admin, TPO, Faculty, Student dashboards).
- [x] **[COMPLETED] Blocked/Waiting Screen for Students**: Post-login gate checking `approval_status == 'pending'` (`PendingApprovalScreen`).
- [ ] **[PENDING] Production Live Auth Verification**: Verification of live SMTP email link reset and production Supabase auth triggers.

---

### 2. Admin Module
- [x] Appoint TPO account functionality in `AdminAccountRepository`.
- [x] Admin Dashboard layout (`AdminDashboardScreen`).
- [x] **[COMPLETED] Appoint TPO UI**: Form to create/assign TPO accounts (`TpoAppointmentScreen`).
- [x] **[COMPLETED] Academic Cycle Management**: UI for creating/editing academic cycles (`SystemSettingsScreen`).
- [x] **[COMPLETED] NAAC / NBA Institution-wide Reporting**: UI to view rollup stats & export reports to PDF and XLSX (`AdminReportsScreen`).
- [ ] **[PENDING] End-to-End Live Backend Sync**: Live backend table syncing for multi-year archive cycles.

---

### 3. TPO Module (Placement Cell)
- [x] `TpoRepository` methods for drive management and stats fetching.
- [x] TPO Command Center Dashboard (`TpoDashboardScreen`).
- [x] **[COMPLETED] Faculty Coordinator Appointment UI**: Assign Faculty Coordinators per department.
- [x] **[COMPLETED] Company Management**: CRUD interface for managing onboarded companies.
- [x] **[COMPLETED] Drive Management & Multi-Step Wizard**: `DriveCreationWizard` (role, CTC, JD, eligibility criteria, branches, CGPA cutoff, backlog limit, round counts).
- [x] **[COMPLETED] Applicant List & Shortlist Upload**: View list of applicants & bulk CSV shortlist parser (`ApplicantListScreen`).
- [ ] **[PENDING] Manual Exception Justification Persistence**: Full database trigger binding for manual eligibility overrides.

---

### 4. Faculty Coordinator Module
- [x] `FacultyRepository` for department-scoped operations.
- [x] Faculty Dashboard layout (`FacultyDashboardScreen`).
- [x] **[COMPLETED] Student Pending Approval Queue**: `StudentApprovalQueueScreen` (approve/reject with reason).
- [x] **[COMPLETED] Department Placement History View**: Department-scoped statistics display.
- [x] **[COMPLETED] Department Drive Attendance View**: Track student attendance per drive round.
- [ ] **[PENDING] Multi-Panel Live Scoring**: Real-time aggregation across simultaneous interview panels.

---

### 5. Student Module
- [x] `StudentDriveRepository` & `StudentApplicationRepository`.
- [x] Student Dashboard (`StudentDashboardScreen`).
- [x] **[COMPLETED] Multi-Step Profile Completion UI**: `ProfileSetupScreen` (academic records, document upload bindings, skills).
- [x] **[COMPLETED] Student Placement Consent Form**: `ConsentFormScreen` (`opted_in` / `opted_out` toggle with reason).
- [x] **[COMPLETED] Eligible Drives Screen**: `EligibleDrivesScreen` (filtered drives).
- [x] **[COMPLETED] My Applications & Status Tracker**: Real-time status tracker (Applied → Shortlisted → Interview → Selected/Rejected).
- [ ] **[PENDING] Direct Supabase Storage Bucket File Pickers**: Native OS file picker integration for document uploads.

---

### 6. Technical & Cross-Cutting Dependencies
- [x] Local SQLite/Drift offline queue database.
- [x] Network connectivity listener & sync provider.
- [x] RLS policies & recursive query bug fix (`00006_fix_profiles_rls_recursion.sql`).
- [x] **[COMPLETED] PDF / XLSX Export Package**: Integrated `pdf`, `excel`, and `printing` packages.
- [x] **[COMPLETED] CSV Parser Integration**: Integrated `csv` parser.
- [x] **[COMPLETED] Unit & Widget Tests**: 22 unit & widget tests passed.
- [ ] **[PENDING] Live FCM Production Credentials**: Setup production Firebase Cloud Messaging server key & APNs certificate.
