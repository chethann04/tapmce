import 'dart:typed_data';

/// Value object carrying all data collected during the student onboarding wizard.
/// Passed to [StudentProfileRepository.saveOnboardingProfile].
class StudentOnboardingData {
  // ── Step 1: Personal Information ─────────────────────────────────────────
  final String fullName;
  final String? phone;
  final DateTime? dob;
  final String? gender;

  /// Bytes of the selected profile photo (null if not selected).
  final Uint8List? photoBytes;
  final String? photoFileName;
  /// Already-uploaded photo URL (when editing existing profile).
  final String? existingPhotoUrl;

  // ── Step 2: Academic Information & Course Recognition ────────────────────
  final String? usn;
  final String? detectedCourseId;
  final String? detectedCourseCode;
  final String? detectedCourseName;
  final int? semester;
  final String? section;
  final int? admissionYear;
  final int? graduationYear;

  // ── Step 3: Education ────────────────────────────────────────────────────
  final double sslcPercent;
  final double pucOrDiplomaPercent;
  final double cgpa;
  final int activeBacklogs;

  // ── Step 4: Resume ───────────────────────────────────────────────────────
  /// Bytes of the selected resume PDF (null if not selected or already uploaded).
  final Uint8List? resumeBytes;
  final String? resumeFileName;
  /// Already-uploaded resume URL (when editing existing profile).
  final String? existingResumeUrl;

  const StudentOnboardingData({
    required this.fullName,
    this.phone,
    this.dob,
    this.gender,
    this.photoBytes,
    this.photoFileName,
    this.existingPhotoUrl,
    this.usn,
    this.detectedCourseId,
    this.detectedCourseCode,
    this.detectedCourseName,
    this.semester,
    this.section,
    this.admissionYear,
    this.graduationYear,
    required this.sslcPercent,
    required this.pucOrDiplomaPercent,
    required this.cgpa,
    required this.activeBacklogs,
    this.resumeBytes,
    this.resumeFileName,
    this.existingResumeUrl,
  });
}
