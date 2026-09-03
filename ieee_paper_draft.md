# Placement Connect: AI-Powered Placement Management System

**Shrirangaraju D**  
Dept. of Information Science & Eng.  
Malnad College of Engineering  
Hassan, India  
4MC23IS103  

**Sakshi Yogesh**  
Dept. of Information Science & Eng.  
Malnad College of Engineering  
Hassan, India  
4MC23IS092  

**Sumukha H S**  
Dept. of Information Science & Eng.  
Malnad College of Engineering  
Hassan, India  
4MC23IS112  

**Shobhitha P**  
Dept. of Information Science & Eng.  
Malnad College of Engineering  
Hassan, India  
4MC23IS100  

**Nithin N K**  
Assistant Professor, Dept. of ISE  
Malnad College of Engineering  
Hassan, India  
nithin.ise@mcehassan.ac.in  

---

## Abstract
The Placement Management System (PMS), titled *Placement Connect*, is a full-stack application designed to digitize and automate the campus recruitment lifecycle of an engineering college. The system addresses the critical limitations of existing manual processes such as fragmented student data, delayed eligibility verification, and the absence of structured mock interview preparation. The proposed solution establishes a multi-role ecosystem comprising three primary users—the Training & Placement (TP) Officer, Faculty, and Students—alongside an AI Engine. These entities interact through a responsive interface backed by a robust backend and relational database. 

The TP Officer manages recruitment drives with precise eligibility criteria, including CGPA thresholds, department filters, and backlog limits. Faculty members onboard and maintain student records via bulk CSV uploads. Students apply to eligible drives, track their progress through each recruitment round, and prepare using an embedded AI Mock Interview module. The AI module evaluates aptitude performance and visual cues—such as posture, eye contact, and confidence—to compute a Readiness Score. This score is persisted in the database and displayed on the student’s dashboard, enabling continuous self-improvement. Ultimately, the system significantly improves transparency, efficiency, and data integrity in the placement process.

**Index Terms**—Placement Management System, AI Mock Interview, Natural Language Processing, Readiness Score, Automation, Role-Based Access Control.

---

## I. INTRODUCTION

### A. Overview
Campus placements form the cornerstone of an engineering student’s academic journey. The process of managing hundreds of students, multiple visiting companies, and varied eligibility criteria is a logistically complex task. Traditional approaches rely heavily on spreadsheets, manual verification, and email-based communications—methods that are prone to errors, delays, and data loss. 

The Placement Management System (PMS) is conceived to eliminate these inefficiencies. It provides a unified digital platform where all stakeholders—the TP Officer, Faculty, and Students—interact in real-time. The system automates drive publication, eligibility filtering, application processing, and status tracking. Its most innovative feature is an embedded AI Mock Interview module that prepares students for actual placement rounds.

*(Note: This research was supported by the Department of Information Science & Engineering, Malnad College of Engineering, Hassan, Karnataka, India.)*

### B. Problem Statement
Engineering colleges face recurring challenges in their placement processes:
*   Student data is maintained across multiple, inconsistent Excel sheets, leading to redundancy and data conflicts.
*   Eligibility verification for each drive is manual and time-consuming, often requiring Faculty to liaise with the TP Officer repeatedly.
*   There is no structured mechanism for students to practice aptitude tests and mock interviews before actual placement drives.
*   Placement status updates are communicated through informal channels (e.g., WhatsApp, notice boards), leading to missed opportunities.
*   Year-end reporting on placement statistics requires significant manual effort from the TP Officer.

### C. Objectives
The core objectives of the system are to:
*   Develop a centralized, role-based web platform to manage the end-to-end placement process.
*   Automate eligibility filtering so students are only shown drives they qualify for.
*   Integrate an AI-powered mock interview system for aptitude testing and visual behavioral analysis.
*   Provide real-time status tracking for students and comprehensive reporting for administrators.
*   Ensure data security, integrity, and scalability to accommodate peak placement season loads.

### D. Scope of the Project
The system is scoped for use within a single engineering college and covers the following domains:
*   User authentication and role management for TP Officers, Faculty, and Students.
*   Full placement drive lifecycle: creation, publication, application, round management, and closure.
*   Bulk student data management via CSV upload and individual profile editing.
*   AI Mock Interview: aptitude question delivery, video capture, NLP evaluation, and visual analysis.
*   Analytics and reporting module for placement statistics across departments and academic years.

*The system does not cover external job portals, company HR systems, or alumni tracking beyond the placement year.*

---

## II. LITERATURE SURVEY & RESEARCH GAP ANALYSIS

### A. Review of Existing Systems
Various studies and commercial products have addressed segments of the placement management problem:
*   **OPUSCONNECT:** Addressed communication bottlenecks between departmental heads and the placement office. Proved that decentralized entry increases data accuracy by 30% because coordinators know student histories. However, it lacks student training or AI modules.
*   **PlacementPrep:** Integrated preparation into placement workflows using ML mock tests, showing a 25% higher selection rate in Tier-1 firms, but lacked visual behavioral feedback.
*   **Placement Portal Management:** Replaced paper notice boards with a secure RBAC repository, speeding candidate search from hours to seconds, but relied on older monolithic architectures.
*   **Smart Campus Placement System:** Used NLP resume parsing to reduce screening time by 70%, but remained entirely recruiter-centric.
*   **Job Portal Development:** Centralized notification engine increased participation by 40%, but lacked student readiness monitoring.
*   **AI in Recruitment Review:** Validated AI models for assessing soft skills (confidence, speech clarity) via non-verbal cues.
*   **E-learning for IT Aspirants:** Proved domain quizzes are 3x more effective than general aptitude, though the quizzes were static.
*   **Job Crafter:** Standardized student profiles via automated resume generation, improving the college brand image.
*   **Online Training and Placement System:** Managed placement archives for NBA/NAAC accreditation, saving 100+ audit preparation hours.

### B. Research Gap Analysis
A significant research gap exists across four domains:
1.  **Absence of Integrated Visual AI:** Prior systems discuss AI for filtering or static tests, but none integrate Visual AI (postural and confidence analysis) to monitor body language during mock sessions.
2.  **Lack of Hierarchical Decentralization:** Systems lack a platform allowing departmental faculty to own student data while providing AI interrogation under one unified TP dashboard.
3.  **Static vs. Interactive Training:** Existing training modules rely on static quizzes. A gap exists for an AI Interrogator that dynamically evaluates aptitude in real-time and syncs scores for TP review.
4.  **Disconnected Lifecycle:** Systems are either management-focused or preparation-focused. No single point of truth manages the lifecycle from Onboarding (Faculty) → Training (AI) → Selection (TP Officer).

---

## III. REQUIREMENT ANALYSIS

### A. Existing vs. Proposed System Analysis
The existing system relies on departmental Excel files, manual verification taking hours, informal notice boards, and manual year-end reporting without mock preparation. 
The proposed system introduces a centralized database, an automated eligibility engine, an embedded AI Mock Interview module, a responsive dashboard connected to a REST API, and one-click report generation.

### B. Functional Requirements
*   **TP Officer:** Manage Faculty Coordinator accounts; orchestrate placement drives with metadata (company name, role, CTC, date); define dynamic eligibility filters (e.g., minimum 7.5 CGPA, no active backlogs); monitor master dashboards across departments; export statistics to PDF or Excel.
*   **Faculty Coordinator:** Bulk student registration via CSV/Excel upload; manual verification of marks, CGPA, and backlogs; department-specific student tracking; broadcast departmental alerts.
*   **Student User:** View profile and personal Placement Readiness Score; view personalized eligible drives and apply with a single click; access AI aptitude testing with instant feedback; record webcam mock interviews analyzed for posture, confidence, and speech; track application history and round status.
*   **System & AI Modules:** Role authentication and redirection; automated locking of the *Apply* button for ineligible students; AI scoring logic updating the database; real-time dashboard status updates.

### C. Non-Functional Requirements
The platform satisfies:
*   **Scalability:** Handle 500+ concurrent users with horizontal scaling.
*   **Security:** Passwords securely hashed; endpoints protected by JWT and CSRF protection.
*   **Data Integrity:** Relational database foreign key constraints and transaction rollbacks.
*   **Availability:** Core portal available 24/7; AI module guaranteed 99.5% uptime via health checks.
*   **Performance:** API response time under 500ms; page loads under 3 seconds.
*   **Usability:** Responsive UI scaling from mobile (375px) to desktop (1920px).

---

## IV. SYSTEM MODELLING AND DESIGN

### A. System Models
**1) Use Case Model:** Four system actors interact with the functional modules:
*   **TP Officer:** Manage Drives, View Reports, Manage Users.
*   **Faculty:** Upload Student Data, Verify Student Eligibility, Monitor Department Progress.
*   **Student:** Update Profile, Apply for Drive, AI Mock Interview, View Results.
*   **AI Engine:** Analyze & Score Interview, Evaluate Response, Write Readiness Score to DB.

**2) Flowchart and Process Logic:** A student’s journey follows distinct stages:
1.  Launch portal and enter credentials.
2.  Auth Check against the users table.
3.  Dashboard rendering (profile, eligible drives, readiness score, placement status).
4.  Browse active drives.
5.  Eligibility Check evaluating CGPA, department, backlog, and attendance criteria.
6.  Apply (system records application with timestamp).
7.  AI Mock Interview prompt (camera and microphone permissions requested).
8.  Attempt interview or defer.
9.  AI Evaluation (aptitude answers + video posture/facial data).
10. Score Saved (Readiness Score written to DB, dashboard updated, email notification sent).
11. Drive Rounds progression: Written Test → Technical → HR.
12. Outcome Decision: Placed or Rejected.

**3) Sequence Diagram of the AI Mock Interview:**
The mock interview execution coordinates discrete chronological message steps:
1.  User clicks “Start Mock Interview”.
2.  Frontend sends start request with JWT to Backend REST API.
3.  Backend executes SELECT questions against the Database.
4.  Database returns question set.
5.  Backend returns Session ID & Time Limit.
6.  Frontend renders UI and countdown timer.
7.  User submits answers + video stream.
8.  Frontend sends submission to Backend.
9.  Backend forwards answers to AI NLP Module.
10. NLP Module returns score and weak areas.
11. Backend passes video to AI Vision Module for analysis.
12. Vision Module returns visual metrics (Posture, Eye Contact, Confidence).
13. Backend executes INSERT scores into Database.
14. Database returns Commit OK.
15. Backend returns Aggregate Score & Feedback.
16. Frontend renders Readiness Score Dashboard.

**4) Entity-Relationship (ER) Schema:**
The relational database structure is normalized across core relational entities:
*   **Departments:** dept_id (PK), dept_name, hod_name, total_students.
*   **Users:** user_id (PK), name, email, password_hash, role, department_id (FK).
*   **Students:** student_id (PK), user_id (FK), roll_no, cgpa, backlogs, attendance_pct, readiness_score, placement_status.
*   **Placement Drives:** drive_id (PK), company_name, visit_date, min_cgpa, allowed_depts, package_lpa, max_backlogs, drive_status, created_by (FK).
*   **Applications:** app_id (PK), student_id (FK), drive_id (FK), applied_at, round_status, last_updated.
*   **Questions:** q_id (PK), question_text, type, correct_answer, marks, difficulty.
*   **Student Answers:** answer_id (PK), session_id (FK), q_id (FK), student_answer, is_correct.
*   **Interview Sessions:** session_id (PK), student_id (FK), started_at, ended_at, aptitude_score, posture_score, eye_contact_score, confidence_index.

**5) State Transition Model:** 
The lifecycle of an application transitions through guard conditions:
`[Initial] → APPLIED → WRITTEN TEST SCHEDULED → WRITTEN TEST CLEARED → TECHNICAL ROUND → HR ROUND → PLACED → [Final]`
*(Failing any stage transitions the application to REJECTED, allowing students to apply to other active drives).*

---

## V. READINESS FORMULATION AND AI SCORING LOGIC

The AI scoring logic processes visual and textual data from the interrogation modules to compute a numerical score. The Readiness Score ($R$) is computed by aggregating aptitude performance with visual behavioral cues:

$$R = w_1A + w_2P + w_3E + w_4C$$

Where:
*   **$A$** = Aptitude Score (computed from evaluated MCQ and descriptive question marks)
*   **$P$** = Posture Score (measures physical posture alignment and movement stability)
*   **$E$** = Eye Contact Score (measures gaze retention and direct camera engagement ratio)
*   **$C$** = Confidence Index (synthesized soft-skill evaluation of facial cues and speech demeanor)
*   **$w_1, w_2, w_3, w_4$** = Normalized empirical weights where $\sum w_i = 1.0$.

The resulting aggregate score is written to the database, updating the student’s dashboard to guide targeted self-improvement.

---

## VI. CONCLUSION

The system modeling and design phase establishes a definitive blueprint for the Placement Management System. By transitioning from abstract functional requirements to concrete Use Case, Flowchart, Sequence, ER, and State Transition Diagrams, the complex interactions between the TP Officer, Departmental Faculty, Students, and AI training modules have been mapped. 

The design specifically addresses the decentralized management gap by creating a robust Role-Based Access Control system, while the integration of a modern architecture backed by a relational database ensures the system operates both as an administrative governance tool and as an interactive training platform. This foundation ensures a scalable, secure, and intelligent portal capable of bridging engineering education with corporate recruitment.

---

## ACKNOWLEDGMENT

The authors express their heartfelt gratitude to the Department of Information Science & Engineering, Malnad College of Engineering, for providing an excellent platform and resources to work on this major project. Sincere thanks are extended to project guide **Mr. Nithin N K** for invaluable guidance, **Dr. Ananda Babu J** (Head of the Department) for research facilities, **Dr. Amarendra H J** (Principal), and Dean AA **Dr. Nanditha B R** for their constant support.
