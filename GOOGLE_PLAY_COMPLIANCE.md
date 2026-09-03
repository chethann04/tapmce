# GOOGLE PLAY COMPLIANCE DECLARATIONS

**Application Name:** Placement Connect  
**Package Name:** `com.placementconnect.app`  
**Target SDK:** Android 14+ (API Level 34/35)  
**Target Audience:** College / University Students & Placement Administrators (18+)  

---

## 1. Data Safety Declarations

### Data Collected & Shared
- **Personal Info**: Name, Email, Phone number, Student USN (Collected for app functionality; account management & placement processing).
- **Files & Documents**: Resumes, Certificates (PDF/Images) uploaded by user for job applications.
- **Device Identifiers**: FCM Registration Token (for push notification delivery).

### Security Practices
- **Data Encrypted in Transit**: Yes (HTTPS / TLS 1.3).
- **Account Deletion Mechanism**: Yes (Self-service in app under **Settings -> Account -> Delete Account**).
- **Data Sharing**: Data is strictly shared with recruiters and placement officers for recruitment purposes only. Data is NEVER sold to third-party ad networks.

---

## 2. Permission Disclosures (`AndroidManifest.xml`)

| Permission | Purpose | Trigger Timing |
| :--- | :--- | :--- |
| `INTERNET` | API requests to Supabase backend & Firebase FCM | App Startup |
| `POST_NOTIFICATIONS` | Alerting students of drive shortlists & interview slots | Prompted on home screen |
| `CAMERA` | Profile picture capture & Drive attendance QR scanner | Explicitly when user clicks Camera |
| `READ_MEDIA_IMAGES` | Selecting profile photo from gallery | Explicitly when user clicks Photo Gallery |

---

## 3. Account Deletion Disclosure URL
- **Deletion Request URL**: `https://placementconnect.org/privacy#account-deletion` [REQUIRES OFFICIAL DEPLOYMENT URL]
- **In-App Deletion Path**: Profile -> Settings -> Delete Account.
