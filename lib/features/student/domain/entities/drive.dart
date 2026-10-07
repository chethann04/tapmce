class Drive {
  final String id;
  final String companyId;
  final String companyName;
  final String roleTitle;
  final String ctcOrStipend;
  final String jobDescription;
  final List<String> eligibilityBranches;
  final double cgpaCutoff;
  final int backlogLimit;
  final DateTime? startDate;
  final DateTime? deletedAt;
  final DateTime applicationDeadline;
  final String status;
  final int roundsCount;
  final List<Map<String, dynamic>> rounds;

  Drive({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.roleTitle,
    required this.ctcOrStipend,
    required this.jobDescription,
    required this.eligibilityBranches,
    required this.cgpaCutoff,
    required this.backlogLimit,
    this.startDate,
    this.deletedAt,
    required this.applicationDeadline,
    required this.status,
    this.roundsCount = 0,
    this.rounds = const [],
  });

  /// True if drive is soft-deleted or has passed the 1-week auto-deletion threshold after deadline
  bool get isDeleted {
    if (deletedAt != null) return true;
    final autoDeleteDate = applicationDeadline.add(const Duration(days: 7));
    if (DateTime.now().isAfter(autoDeleteDate)) return true;
    return false;
  }

  /// True if the drive applications have not opened yet
  bool get isUpcoming {
    if (isDeleted) return false;
    if (isClosed) return false;
    if (status.toLowerCase() == 'upcoming') return true;
    if (startDate != null && startDate!.isAfter(DateTime.now())) return true;
    return false;
  }

  /// True if the drive is closed (manually or deadline passed)
  bool get isClosed {
    if (deletedAt != null) return true;
    final s = status.toLowerCase();
    if (s == 'closed' || s == 'completed' || s == 'cancelled') return true;
    if (applicationDeadline.isBefore(DateTime.now())) return true;
    return false;
  }

  /// True if drive is currently open/active for applications
  bool get isActive => !isDeleted && !isUpcoming && !isClosed;

  factory Drive.fromMap(Map<String, dynamic> map) {
    String extractedCompanyName = '';
    
    if (map['company'] != null) {
      if (map['company'] is Map) {
        final companyMap = map['company'] as Map<String, dynamic>;
        extractedCompanyName = companyMap['name'] as String? ?? 
                               companyMap['company'] as String? ?? '';
      } else if (map['company'] is String) {
        extractedCompanyName = map['company'] as String;
      }
    } else if (map['companies'] != null) {
      if (map['companies'] is Map) {
        final companyMap = map['companies'] as Map<String, dynamic>;
        extractedCompanyName = companyMap['name'] as String? ?? '';
      } else if (map['companies'] is String) {
        extractedCompanyName = map['companies'] as String;
      }
    }
    
    if (extractedCompanyName.isEmpty) {
      extractedCompanyName = map['company_name'] as String? ?? 
                             map['companyName'] as String? ?? '';
    }

    // Extract package LPA/CTC display string safely
    String ctcDisplay = 'Disclosed on selection';
    if (map['package_lpa'] != null) {
      ctcDisplay = '₹${map['package_lpa']} LPA';
    } else if (map['ctc_or_stipend'] != null || map['ctcOrStipend'] != null || map['ctc'] != null) {
      ctcDisplay = (map['ctc_or_stipend'] ?? map['ctcOrStipend'] ?? map['ctc']).toString();
    }

    // Extract description
    final desc = map['description'] as String? ?? map['job_description'] as String? ?? map['jobDescription'] as String? ?? '';

    // Extract role
    final roleName = map['role_title'] as String? ?? map['role'] as String? ?? 'Job Role';

    // Extract CGPA cutoff
    final cgpaVal = (map['eligibility_cgpa'] as num?)?.toDouble() ?? (map['cgpa_cutoff'] as num?)?.toDouble() ?? 0.0;

    // Extract start date (start_date or application_start_date)
    final startDateStr = map['start_date'] as String? ?? map['application_start_date'] as String?;
    final startDate = startDateStr != null ? DateTime.tryParse(startDateStr) : null;

    // Extract deleted at
    final deletedAtStr = map['deleted_at'] as String?;
    final deletedAt = deletedAtStr != null ? DateTime.tryParse(deletedAtStr) : null;

    // Extract deadline date (end_date or application_deadline)
    final deadlineStr = map['end_date'] as String? ?? map['application_deadline'] as String? ?? '';
    final deadlineDate = DateTime.tryParse(deadlineStr) ?? DateTime.now().add(const Duration(days: 14));

    return Drive(
      id: map['id'] as String? ?? '',
      companyId: map['company_id'] as String? ?? '',
      companyName: extractedCompanyName,
      roleTitle: roleName,
      ctcOrStipend: ctcDisplay,
      jobDescription: desc,
      eligibilityBranches: List<String>.from(map['eligibility_branches'] ?? map['eligibilityBranches'] ?? []),
      cgpaCutoff: cgpaVal,
      backlogLimit: map['backlog_limit'] as int? ?? map['backlogLimit'] as int? ?? 0,
      startDate: startDate,
      deletedAt: deletedAt,
      applicationDeadline: deadlineDate,
      status: map['status'] as String? ?? 'upcoming',
      roundsCount: map['rounds_count'] as int? ?? 0,
      rounds: (map['drive_rounds'] as List?)?.cast<Map<String, dynamic>>() ??
              (map['rounds'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
  }
  // Compatibility getters for legacy UI code
  List<String> get targetBranches => eligibilityBranches;
  double get minCgpa => cgpaCutoff;
  int get maxBacklogs => backlogLimit;
  DateTime get deadline => applicationDeadline;
  String get description => jobDescription;

}