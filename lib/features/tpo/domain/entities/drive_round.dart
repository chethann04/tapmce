class DriveRound {
  final String id;
  final String driveId;
  final int roundNumber;
  final String roundName;
  final DateTime? roundDate;
  final String? roundTime;
  final String? venueOrLink;
  final String? instructions;
  final DateTime? scheduledDate;
  final String createdBy;
  final DateTime createdAt;

  DriveRound({
    required this.id,
    required this.driveId,
    required this.roundNumber,
    required this.roundName,
    this.roundDate,
    this.roundTime,
    this.venueOrLink,
    this.instructions,
    this.scheduledDate,
    required this.createdBy,
    required this.createdAt,
  });

  factory DriveRound.fromMap(Map<String, dynamic> map) {
    return DriveRound(
      id: map['id'] as String? ?? '',
      driveId: map['drive_id'] as String? ?? '',
      roundNumber: map['round_number'] as int? ?? 0,
      roundName: map['round_name'] as String? ?? '',
      roundDate: map['round_date'] != null ? DateTime.tryParse(map['round_date'].toString()) : null,
      roundTime: map['round_time'] as String?,
      venueOrLink: map['venue_or_link'] as String?,
      instructions: map['instructions'] as String?,
      scheduledDate: map['scheduled_date'] != null ? DateTime.tryParse(map['scheduled_date'].toString()) : null,
      createdBy: map['created_by'] as String? ?? '',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'drive_id': driveId,
      'round_number': roundNumber,
      'round_name': roundName,
      'round_date': roundDate?.toIso8601String().split('T').first,
      'round_time': roundTime,
      'venue_or_link': venueOrLink,
      'instructions': instructions,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'created_by': createdBy,
    };
  }
}
