
enum AuditAction {
  login,
  verification,
  rejection,
  driveCreated,
  optIn,
  optOut,
  roleChange,
  other,
}

AuditAction parseAuditAction(String actionStr) {
  switch (actionStr.toLowerCase()) {
    case 'login': return AuditAction.login;
    case 'verification': return AuditAction.verification;
    case 'rejection': return AuditAction.rejection;
    case 'drive_created': return AuditAction.driveCreated;
    case 'opt_in': return AuditAction.optIn;
    case 'opt_out': return AuditAction.optOut;
    case 'role_change': return AuditAction.roleChange;
    default: return AuditAction.other;
  }
}

String formatAuditAction(AuditAction action) {
  switch (action) {
    case AuditAction.login: return 'login';
    case AuditAction.verification: return 'verification';
    case AuditAction.rejection: return 'rejection';
    case AuditAction.driveCreated: return 'drive_created';
    case AuditAction.optIn: return 'opt_in';
    case AuditAction.optOut: return 'opt_out';
    case AuditAction.roleChange: return 'role_change';
    case AuditAction.other: return 'other';
  }
}

class AuditLogEntry {
  final String id;
  final String actorId;
  final String actorName;
  final String actorRole;
  final AuditAction action;
  final String? targetTable;
  final String? targetId;
  final Map<String, dynamic>? details;
  final DateTime timestamp;
  final String description;

  const AuditLogEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    this.targetTable,
    this.targetId,
    this.details,
    required this.timestamp,
    required this.description,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return AuditLogEntry(
      id: (json['id'] as String?) ?? '',
      actorId: (json['actor_id'] as String?) ?? '',
      actorName: (profile?['name'] as String?) ?? 'Unknown User',
      actorRole: (profile?['role'] as String?) ?? 'Unknown Role',
      action: parseAuditAction((json['action'] as String?) ?? 'other'),
      targetTable: json['target_table'] as String?,
      targetId: json['target_id'] as String?,
      details: json['details'] as Map<String, dynamic>?,
      timestamp: _parseTimestamp(json['created_at']),
      description: (json['details'] as Map<String, dynamic>?)?['description'] as String? ?? 'Performed an action',
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value as String);
    } catch (_) {
      return DateTime.now();
    }
  }
}
