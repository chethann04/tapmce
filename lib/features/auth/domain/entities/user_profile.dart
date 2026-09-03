import '../../../../core/utils/usn_parser.dart';

enum UserRole {
  admin,
  tpo,
  facultyCoordinator,
  faculty,
  student;

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'tpo':
        return UserRole.tpo;
      case 'faculty_coordinator':
        return UserRole.facultyCoordinator;
      case 'faculty':
        return UserRole.faculty;
      case 'student':
        return UserRole.student;
      default:
        throw ArgumentError('Unknown role value: "$value". Check the profiles table.');
    }
  }

  String get dbValue {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.tpo:
        return 'tpo';
      case UserRole.facultyCoordinator:
        return 'faculty_coordinator';
      case UserRole.faculty:
        return 'faculty';
      case UserRole.student:
        return 'student';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.tpo:
        return 'TPO Officer';
      case UserRole.facultyCoordinator:
        return 'Faculty Coordinator';
      case UserRole.faculty:
        return 'Faculty Member';
      case UserRole.student:
        return 'Student';
    }
  }
}

enum ApprovalStatus {
  pending,
  approved,
  rejected;

  static ApprovalStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'approved':
        return ApprovalStatus.approved;
      case 'rejected':
        return ApprovalStatus.rejected;
      default:
        return ApprovalStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case ApprovalStatus.pending:
        return 'Pending Verification';
      case ApprovalStatus.approved:
        return 'Approved';
      case ApprovalStatus.rejected:
        return 'Rejected';
    }
  }
}

enum ConsentStatus {
  notSet,
  optedIn,
  optedOut;

  static ConsentStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'opted_in':
        return ConsentStatus.optedIn;
      case 'opted_out':
        return ConsentStatus.optedOut;
      default:
        return ConsentStatus.notSet;
    }
  }
}

/// Represents a user's profile from the `profiles` table in Supabase.
class UserProfile {
  final String id;
  final UserRole role;
  final String name;
  final String email;
  final String? phone;

  // Student specific
  final String? usn;
  final String? department;
  final String? batch;
  final double? tenthPercent;
  final double? twelfthOrDiplomaPercent;
  final double? cgpa;
  final int activeBacklogs;
  final String? resumeUrl;
  final String? photoUrl;
  final String? idProofUrl;
  final List<String> skills;
  final int? semester;
  final String? section;
  final int? admissionYear;
  final int? graduationYear;
  final bool emailVerified;
  final bool profileCompleted;
  final DateTime? dob;
  final String? gender;

  // Centralized Course Tracking (USN detected vs Faculty verified)
  final String? detectedCourseId;
  final String? detectedCourseCode;
  final String? detectedCourseName;
  final String? verifiedCourseId;
  final String? verifiedCourseCode;
  final String? verifiedCourseName;
  final String branchSource;
  final bool branchVerified;

  final ConsentStatus consentStatus;
  final String? consentReason;

  // Approval gate: student blocked from applying until approved by Faculty Coordinator
  final ApprovalStatus approvalStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;

  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    this.phone,
    this.usn,
    this.department,
    this.batch,
    this.tenthPercent,
    this.twelfthOrDiplomaPercent,
    this.cgpa,
    this.activeBacklogs = 0,
    this.resumeUrl,
    this.photoUrl,
    this.idProofUrl,
    this.skills = const [],
    this.semester,
    this.section,
    this.admissionYear,
    this.graduationYear,
    this.emailVerified = false,
    this.profileCompleted = false,
    this.dob,
    this.gender,
    this.detectedCourseId,
    this.detectedCourseCode,
    this.detectedCourseName,
    this.verifiedCourseId,
    this.verifiedCourseCode,
    this.verifiedCourseName,
    this.branchSource = 'usn',
    this.branchVerified = false,
    this.consentStatus = ConsentStatus.notSet,
    this.consentReason,
    this.approvalStatus = ApprovalStatus.pending,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper alias for existing UI code compatibility
  String get fullName => name;
  String? get rollNumber => usn;

  /// Returns the effective authorized course code (verified preferred, fallback to detected or parsed USN).
  String get effectiveCourseCode =>
      verifiedCourseCode ?? detectedCourseCode ?? UsnParser.extractBranchCode(usn ?? '') ?? '';

  /// Returns the effective display course name.
  String get effectiveCourseName =>
      verifiedCourseName ?? detectedCourseName ?? department ?? 'General Engineering';

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      role: UserRole.fromString(map['role'] as String? ?? 'student'),
      name: map['name'] as String? ?? map['full_name'] as String? ?? 'User',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      usn: map['usn'] as String? ?? map['roll_number'] as String?,
      department: map['department'] as String?,
      batch: map['batch'] as String?,
      tenthPercent: (map['tenth_percent'] as num?)?.toDouble(),
      twelfthOrDiplomaPercent: (map['twelfth_or_diploma_percent'] as num?)?.toDouble(),
      cgpa: (map['cgpa'] as num?)?.toDouble(),
      activeBacklogs: map['active_backlogs'] as int? ?? 0,
      resumeUrl: map['resume_url'] as String?,
      photoUrl: map['photo_url'] as String?,
      idProofUrl: map['id_proof_url'] as String?,
      skills: (map['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      semester: map['semester'] as int?,
      section: map['section'] as String?,
      admissionYear: map['admission_year'] as int?,
      graduationYear: map['graduation_year'] as int?,
      emailVerified: map['email_verified'] as bool? ?? false,
      profileCompleted: map['profile_completed'] as bool? ?? false,
      dob: map['dob'] != null ? DateTime.tryParse(map['dob'] as String) : null,
      gender: map['gender'] as String?,
      detectedCourseId: map['detected_course_id'] as String?,
      detectedCourseCode: map['detected_course_code'] as String?,
      detectedCourseName: map['detected_course_name'] as String?,
      verifiedCourseId: map['verified_course_id'] as String?,
      verifiedCourseCode: map['verified_course_code'] as String?,
      verifiedCourseName: map['verified_course_name'] as String?,
      branchSource: (map['branch_source'] as String?) ?? 'usn',
      branchVerified: (map['branch_verified'] as bool?) ?? false,
      consentStatus: ConsentStatus.fromString(map['consent_status'] as String?),
      consentReason: map['consent_reason'] as String?,
      approvalStatus: ApprovalStatus.fromString(map['approval_status'] as String?),
      approvedBy: map['approved_by'] as String?,
      approvedAt: map['approved_at'] != null ? DateTime.parse(map['approved_at'] as String) : null,
      rejectionReason: map['rejection_reason'] as String?,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'role': role.dbValue,
        'name': name,
        'email': email,
        'phone': phone,
        'usn': usn,
        'department': department,
        'batch': batch,
        'tenth_percent': tenthPercent,
        'twelfth_or_diploma_percent': twelfthOrDiplomaPercent,
        'cgpa': cgpa,
        'active_backlogs': activeBacklogs,
        'resume_url': resumeUrl,
        'photo_url': photoUrl,
        'id_proof_url': idProofUrl,
        'skills': skills,
        'detected_course_id': detectedCourseId,
        'detected_course_code': detectedCourseCode,
        'detected_course_name': detectedCourseName,
        'verified_course_id': verifiedCourseId,
        'verified_course_code': verifiedCourseCode,
        'verified_course_name': verifiedCourseName,
        'branch_source': branchSource,
        'branch_verified': branchVerified,
        'consent_status': consentStatus.name,
        'consent_reason': consentReason,
        'approval_status': approvalStatus.name,
        'approved_by': approvedBy,
        'approved_at': approvedAt?.toIso8601String(),
        'rejection_reason': rejectionReason,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
