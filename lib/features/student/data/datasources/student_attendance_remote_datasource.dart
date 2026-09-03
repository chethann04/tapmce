import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/email_notification_service.dart';

class StudentAttendanceRemoteDataSource {
  final SupabaseClient _client;
  final EmailNotificationService? _emailService;

  StudentAttendanceRemoteDataSource(this._client, [this._emailService]);

  /// Validates QR payload and inserts attendance record.
  Future<Map<String, dynamic>> markAttendance({
    required String qrPayload,
    required String studentId,
  }) async {
    // 1. Decode and validate QR payload
    final Map<String, dynamic> qrData;
    try {
      qrData = jsonDecode(qrPayload) as Map<String, dynamic>;
    } catch (_) {
      throw AttendanceException('Invalid QR Code', 'QR code data is malformed.');
    }

    if (qrData['type'] != 'tap_drive_attendance') {
      throw AttendanceException('Invalid QR Code', 'This QR code is not for attendance.');
    }

    final driveId = qrData['drive_id'] as String?;
    if (driveId == null || driveId.isEmpty) {
      throw AttendanceException('Invalid QR Code', 'QR code is missing drive information.');
    }

    // 2. Verify drive exists
    final driveResponse = await _client
        .from('drives')
        .select('id, role, company_id, company:companies(name)')
        .eq('id', driveId)
        .maybeSingle();

    if (driveResponse == null) {
      throw AttendanceException('Drive Not Found', 'The drive associated with this QR code no longer exists.');
    }

    // 3. Verify student has applied to this drive
    final application = await _client
        .from('applications')
        .select('id')
        .eq('drive_id', driveId)
        .eq('student_id', studentId)
        .maybeSingle();

    if (application == null) {
      throw AttendanceException('Not Applied to Drive', 'You have not applied for this placement drive. Attendance check-in is only permitted for registered applicants.');
    }

    // 4. Check duplicate attendance
    final existing = await _client
        .from('drive_attendance')
        .select('id')
        .eq('drive_id', driveId)
        .eq('student_id', studentId)
        .maybeSingle();

    if (existing != null) {
      throw AttendanceException('Already Marked', 'You have already marked attendance for this drive.');
    }

    // 4. Get student profile
    final profile = await _client
        .from('profiles')
        .select('name, usn, department')
        .eq('id', studentId)
        .maybeSingle();

    if (profile == null) {
      throw AttendanceException('Profile Error', 'Could not find your student profile.');
    }

    // 5. Insert attendance record (scanned_at automatically set by Postgres default now())
    final inserted = await _client
        .from('drive_attendance')
        .insert({
          'drive_id': driveId,
          'student_id': studentId,
          'status': 'present',
        })
        .select('id, scanned_at')
        .single();

    final scannedAtIso = inserted['scanned_at'] as String?;

    // 6. Build attendance result with drive + student info
    final companyName = driveResponse['company'] is Map
        ? (driveResponse['company'] as Map)['name'] as String? ?? ''
        : '';

    final nowIso = scannedAtIso ?? DateTime.now().toUtc().toIso8601String();

    // Dispatch attendance confirmation email
    if (_emailService != null && profile['email'] != null) {
      try {
        _emailService!.sendAttendanceConfirmationEmail(
          recipientEmail: profile['email'] as String,
          companyName: companyName.isNotEmpty ? companyName : 'Placement Drive',
          date: nowIso.split('T')[0],
          time: nowIso.contains('T') ? nowIso.split('T')[1].substring(0, 5) : '',
        );
      } catch (_) {}
    }

    // Push notification confirming attendance
    try {
      await _client.functions.invoke('send-fcm-push', body: {
        'user_ids': [studentId],
        'drive_id': driveId,
        'title': 'Attendance Confirmed',
        'body': 'Your attendance for ${companyName.isNotEmpty ? companyName : 'the drive'} has been confirmed.',
      });
    } catch (_) {}

    return {
      'id': inserted['id'],
      'drive_id': driveId,
      'student_id': studentId,
      'student_name': profile['name'] as String? ?? '',
      'usn': profile['usn'] as String? ?? '',
      'department': profile['department'] as String? ?? '',
      'company_name': companyName,
      'drive_role': driveResponse['role'] as String? ?? '',
      'scanned_at': nowIso,
      'status': 'present',
    };
  }

  /// Checks if attendance already exists for this student + drive.
  Future<bool> hasAttendance({
    required String studentId,
    required String driveId,
  }) async {
    final existing = await _client
        .from('drive_attendance')
        .select('id')
        .eq('drive_id', driveId)
        .eq('student_id', studentId)
        .maybeSingle();
    return existing != null;
  }
}

class AttendanceException implements Exception {
  final String title;
  final String message;
  const AttendanceException(this.title, this.message);

  @override
  String toString() => '$title: $message';
}
