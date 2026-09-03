import '../../../auth/domain/entities/user_profile.dart';

class DriveAttendanceRecord {
  final String id;
  final String driveId;
  final String studentId;
  final DateTime scannedAt;
  final String status;
  final UserProfile? studentProfile;

  const DriveAttendanceRecord({
    required this.id,
    required this.driveId,
    required this.studentId,
    required this.scannedAt,
    this.status = 'present',
    this.studentProfile,
  });

  factory DriveAttendanceRecord.fromMap(Map<String, dynamic> map) {
    UserProfile? profile;
    if (map['profile'] != null && map['profile'] is Map<String, dynamic>) {
      profile = UserProfile.fromMap(map['profile'] as Map<String, dynamic>);
    }

    return DriveAttendanceRecord(
      id: map['id'] as String,
      driveId: map['drive_id'] as String,
      studentId: map['student_id'] as String,
      scannedAt: map['scanned_at'] != null
          ? DateTime.parse(map['scanned_at'] as String)
          : DateTime.now(),
      status: map['status'] as String? ?? 'present',
      studentProfile: profile,
    );
  }

  Map<String, dynamic> toMap() => {
        'drive_id': driveId,
        'student_id': studentId,
        'scanned_at': scannedAt.toIso8601String(),
        'status': status,
      };
}
