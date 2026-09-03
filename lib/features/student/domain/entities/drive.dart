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
    required this.applicationDeadline,
    required this.status,
    this.roundsCount = 0,
    this.rounds = const [],
  });

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