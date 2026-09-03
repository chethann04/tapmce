# Project Methodology and Implementation

This document outlines the methodology and implementation strategy used to build the **Placement Connect (TAP-APP)** platform from scratch. It serves as a comprehensive guide to the system's architecture, development lifecycle, and technical decisions.

---

## 1. Introduction and Objectives
The objective of this project is to streamline the campus recruitment process by providing a unified, real-time platform for Students, Training and Placement Officers (TPOs), Faculty Coordinators, and Administrators. 

The system aims to solve the following problems:
- Manual tracking of student applications and recruitment stages.
- Lack of real-time communication regarding placement drives.
- Inefficient attendance tracking during physical recruitment rounds.
- Disconnected student profile verification processes.

---

## 2. Technology Stack Selection
The project utilizes a modern, serverless architecture to ensure scalability, rapid development, and cross-platform compatibility.

### Frontend
* **Framework:** **Flutter** (Dart) - Chosen for its ability to compile natively to iOS, Android, and Web from a single codebase, ensuring a consistent UI/UX across all platforms.
* **State Management:** **Riverpod** - Selected for its compile-time safety, testability, and efficient handling of asynchronous data streams.
* **Routing:** **go_router** - Used for robust, declarative, URL-based navigation, which is essential for web support and deep linking.
* **Local Notifications:** **flutter_local_notifications** - For handling foreground alerts and system tray notifications.

### Backend as a Service (BaaS)
* **Platform:** **Supabase** - Chosen as an open-source Firebase alternative, providing a powerful relational database.
* **Database:** **PostgreSQL** - Provides robust relational data modeling, complex querying, and data integrity.
* **Authentication:** **Supabase Auth** - Handles secure user authentication, JWT token generation, and Role-Based Access Control (RBAC).
* **Realtime:** **Supabase Realtime** - Utilized for instant UI updates (e.g., live notifications, application status changes).
* **Push Notifications:** **Firebase Cloud Messaging (FCM)** - Integrated alongside Supabase for reliable background push message delivery.

---

## 3. System Architecture
The application follows a **Clean Architecture** inspired approach, highly modularized by feature.

### 3.1 Directory Structure (Feature-First)
The codebase is structured around business features rather than technical layers. This ensures that as the app grows, modules remain decoupled.
```text
lib/
 â”œâ”€â”€ core/             # Global services, theme, router, constants
 â”œâ”€â”€ shared/           # Reusable UI widgets and cross-feature utilities
 â””â”€â”€ features/         # Feature modules
     â”œâ”€â”€ auth/         # Login, Registration, OTP, RBAC
     â”œâ”€â”€ student/      # Student Dashboard, Profile Setup, Timeline
     â”œâ”€â”€ tpo/          # Drive Creation, Round Management, QR Scanner
     â”œâ”€â”€ faculty/      # Profile Verification Dashboard
     â””â”€â”€ admin/        # System Settings, Role Management
```

### 3.2 Role-Based Access Control (RBAC)
A core architectural pillar is RBAC. When a user authenticates, a secure request is made to the `profiles` table to determine their role (`student`, `tpo`, `faculty`, or `admin`). 
* **Frontend Security:** `go_router` uses a redirect engine to prevent unauthorized access to specific screens based on the current user's role.
* **Backend Security:** PostgreSQL Row Level Security (RLS) policies enforce that users can only read, insert, or modify data they are explicitly permitted to access.

---

## 4. Implementation Methodology
The project was developed using an **Iterative Agile Methodology**. Development was broken down into manageable sprints.

### Phase 1: Foundation & Database Modeling
1. **Schema Design:** Designed the relational database schema in PostgreSQL. Key tables include `profiles`, `drives`, `applications`, `application_round_status`, `drive_attendance`, and `notifications`.
2. **Security:** Implemented RLS policies to ensure students can only view their own applications, while TPOs have holistic access to all drive data.
3. **Core Setup:** Initialized the Flutter project, configured Riverpod, and established the Supabase connection.

### Phase 2: Authentication & Profiles
1. **Login Flow:** Implemented Supabase Authentication (Email/Password & OTP).
2. **Profile Setup:** Built the onboarding flow for students to enter their academic details, USN, and department.
3. **Role Routing:** Configured `go_router` to dynamically route users to their respective dashboards (Student, TPO, Faculty) upon successful login.

### Phase 3: Core Business Logic (Drives & Applications)
1. **TPO Drive Management:** Built the Drive Creation Wizard allowing TPOs to announce companies, set eligibility criteria (CGPA, backlogs), and define recruitment stages.
2. **Student Applications:** Implemented the student-facing drive explorer and the one-click application system. Added the `student_timeline_provider` to allow students to track their progress through various stages visually.
3. **Round Management:** Built the TPO interface for filtering candidates, marking them as passed/rejected for specific rounds, and updating the `application_round_status` table.

### Phase 4: Advanced Features & Refinement
1. **QR Code Attendance:** Implemented a system where TPOs can generate a QR code for a specific drive, and students can scan it to mark attendance (`drive_attendance` table).
2. **Notification System:** 
   - **Backend:** Setup PostgreSQL triggers and Edge Functions to automatically insert rows into the `notifications` table when application statuses change.
   - **Frontend:** Integrated `flutter_local_notifications` and Firebase Cloud Messaging (FCM). The `PushNotificationService` listens to the Supabase Realtime channel for new inserts and fires a local push notification to the user's device.
3. **Email Fallbacks:** Configured an `EmailNotificationService` via Supabase Edge Functions / SMTP to ensure critical alerts reach students even if the app is closed.

---

## 5. Challenges & Solutions

* **Complex State Management:** Managing the UI state of thousands of students across multiple recruitment rounds was complex. 
  * *Solution:* Leveraged Riverpod's `FutureProvider.family` to independently fetch and cache candidate lists for specific rounds, preventing UI lag and unnecessary API calls.
* **Database Schema Migrations:** Over the course of development, certain columns (like `resume_version_url` or `updated_by`) were dropped or refactored.
  * *Solution:* Implemented defensive programming in the data repositories (`tpo_repository_impl.dart`), ensuring that missing columns gracefully fall back or merge with existing tables (like cross-referencing `applications` with `drive_attendance` to rebuild candidate lists dynamically).
* **Push Notification Interoperability:** Ensuring notifications worked seamlessly on both Mobile and Web platforms.
  * *Solution:* Abstracted the notification logic. The app relies on Supabase Realtime for instant Web updates, while utilizing FCM tokens mapped in an `fcm_tokens` table to deliver native OS-level alerts on Android and iOS.

---

## 6. Conclusion
By utilizing Flutter and Supabase, the TAP-APP project successfully achieved a highly responsive, cross-platform application. The feature-first architecture ensures that the codebase is maintainable and scalable. The strict adherence to PostgreSQL RLS guarantees enterprise-grade security, ensuring that sensitive student academic data and placement records remain protected.
