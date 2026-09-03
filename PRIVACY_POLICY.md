# PRIVACY POLICY

**Version:** 1.0  
**Effective Date:** August 23, 2026  
**Last Updated:** August 23, 2026  

> [!NOTE]  
> This Privacy Policy explains how **Placement Connect** ("we", "our", or "the Platform") collects, uses, stores, and protects personal data of students, faculty, Training & Placement Officers (TPOs), and administrators.

---

## 1. Data Controller & Contact Information
- **Deploying Organization:** [REQUIRES OFFICIAL INPUT - e.g., Malnad College of Engineering / Placement Department]
- **Contact Email:** [REQUIRES OFFICIAL INPUT]
- **Data Protection Officer / Grievance Officer:** [REQUIRES OFFICIAL INPUT]

---

## 2. Personal Data We Collect

1. **Account & Profile Data**: Full name, university email, phone number, USN/Roll number, department, branch, passout year, CGPA, profile picture.
2. **Academic & Professional Records**: Resumes (PDF), certificates, marksheets, work experience, skills.
3. **Application & Placement Data**: Job applications, company drive responses, interview schedules, offer letters, attendance records.
4. **Device & Push Notification Data**: Firebase Cloud Messaging (FCM) tokens, APNs device tokens, device OS type.
5. **Security & Audit Logs**: Login timestamps, session activity, password reset logs, OTP verification logs.

---

## 3. How We Use Your Data

* Facilitating university campus placement drives and job applications.
* Verifying student eligibility criteria (CGPA, backlog status, department).
* Delivering real-time push notifications for drive announcements, shortlists, and interview schedules.
* Generating anonymized placement statistics and accreditation reports.

---

## 4. Third-Party Data Processors

| Processor | Purpose | Data Shared | Region |
| :--- | :--- | :--- | :--- |
| **Supabase Inc.** | Core database, Auth, Storage & Edge Functions | Encrypted User profiles, resumes, application records | US / AWS Region |
| **Google Firebase (FCM)** | Push notifications delivery | Anonymized device tokens, alert payloads | Global |
| **Apple (APNs)** | iOS Push notification delivery | Anonymized iOS device tokens | Global |

---

## 5. Account Deletion & Data Subject Rights

Under applicable privacy frameworks (including **Apple App Store Guideline 5.1.1(v)** and **India DPDP Act 2023**), you have the right to:
1. **Request Account Deletion**: Go to **Profile Settings -> Security -> Delete Account** in the mobile app, or contact your Placement Officer.
2. **Access & Export Data**: Request a copy of your stored profile and application history.
3. **Correction**: Update inaccurate academic or contact details via profile settings or TPO approval.

---

## 6. Security Controls

* All data in transit is encrypted using **TLS 1.3**.
* All sensitive files (resumes, marksheets) in storage use private bucket access policies and temporary signed expiring URLs.
* Password hashing and session management are handled via **PKCE-authenticated Supabase Auth**.

---

## 7. Legal Disclaimer
> [!IMPORTANT]  
> **PENDING LEGAL REVIEW**: This document reflects the technical implementation of Placement Connect. Official legal entity details and retention schedules must be reviewed and approved by authorized organizational representatives.
