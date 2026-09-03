enum ApplicationStatus {
  applied,
  shortlisted,
  interview,
  rejected,
  selected;

  static ApplicationStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'shortlisted':
        return ApplicationStatus.shortlisted;
      case 'interview':
        return ApplicationStatus.interview;
      case 'rejected':
        return ApplicationStatus.rejected;
      case 'selected':
        return ApplicationStatus.selected;
      default:
        return ApplicationStatus.applied;
    }
  }

  String get displayName {
    switch (this) {
      case ApplicationStatus.applied:
        return 'Applied';
      case ApplicationStatus.shortlisted:
        return 'Shortlisted';
      case ApplicationStatus.interview:
        return 'Interview';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.selected:
        return 'Selected';
    }
  }
}

class Application {
  final String id;
  final String driveId;
  final String studentId;
  final ApplicationStatus status;
  final DateTime appliedAt;

  /// Preserves the full joined data from Supabase (drive, company, etc.)
  final Map<String, dynamic> rawData;

  Application({
    required this.id,
    required this.driveId,
    required this.studentId,
    required this.status,
    required this.appliedAt,
    this.rawData = const {},
  });

  factory Application.fromMap(Map<String, dynamic> map) {
    return Application(
      id: map['id'] as String? ?? '',
      driveId: map['drive_id'] as String? ?? '',
      studentId: map['student_id'] as String? ?? '',
      status: ApplicationStatus.fromString(map['status'] as String?),
      appliedAt: DateTime.tryParse(map['applied_at'] as String? ?? '') ?? DateTime.now(),
      rawData: map,
    );
  }

  /// Extracts company name from joined drive data.
  String get companyName {
    final drive = rawData['drive'];
    if (drive is Map) {
      final company = drive['company'];
      if (company is Map) {
        return company['name'] as String? ?? 'Company';
      }
      return drive['company_name'] as String? ?? 'Company';
    }
    return 'Company';
  }

  /// Extracts role title from joined drive data.
  String get roleName {
    final drive = rawData['drive'];
    if (drive is Map) {
      return drive['role_title'] as String? ?? drive['role'] as String? ?? 'Placement drive';
    }
    return 'Placement drive';
  }

  /// Extracts CTC/package from joined drive data.
  String get ctcDisplay {
    final drive = rawData['drive'];
    if (drive is Map) {
      return drive['ctc_or_stipend'] as String? ?? drive['package_lpa']?.toString() ?? '';
    }
    return '';
  }
}