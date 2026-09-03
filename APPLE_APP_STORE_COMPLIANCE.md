# APPLE APP STORE COMPLIANCE & REVIEW NOTES

**Application Name:** Placement Connect  
**Bundle Identifier:** `com.placementconnect.app`  
**Platform Target:** iOS 15.0+  

---

## 1. App Privacy Declarations (App Store Connect)

### Data Types Collected
- **Contact Info**: Name, Email Address, Phone Number.
- **User Content**: Photos (Profile picture), Documents (Resumes / Certificates).
- **Identifiers**: User ID (Supabase Auth UUID), Device ID (APNs token).

### Data Linked to User
All data listed above is linked to the user's account identity.

### Data Tracking
Placement Connect **does NOT track users** across third-party apps or websites. `AppTrackingTransparency` framework is not required.

---

## 2. Guideline 5.1.1(v) - In-App Account Deletion
Placement Connect complies with Apple's account deletion policy by providing:
1. **In-App Account Deletion**: Users navigate to **Settings -> Security -> Delete Account**.
2. **Backend Execution**: Triggers Supabase RPC `delete_user_account(user_id)` which deletes Auth credentials and anonymizes personal records.

---

## 3. `Info.plist` Permission Descriptions Review

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take profile photos and scan QR codes.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select profile photos and upload documents.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app needs access to save generated PDF reports and QR codes to your photo library.</string>
<key>NSDocumentsFolderUsageDescription</key>
<string>This app needs access to your documents folder to pick resume and certificate files.</string>
```

---

## 4. App Store Reviewer Test Credentials
```text
Role: Student Demo Account
Email: student.demo@placementconnect.org
Password: DemoStudent123!

Role: TPO (Administrator) Demo Account
Email: tpo.demo@placementconnect.org
Password: DemoTpoAdmin123!
```
