abstract class StudentAttendanceRepository {
  /// Validates the scanned QR payload and marks attendance.
  /// Returns the attendance record map on success.
  /// Throws descriptive errors on failure.
  Future<Map<String, dynamic>> markAttendance({
    required String qrPayload,
    required String studentId,
  });

  /// Checks if attendance already exists for this student + drive.
  Future<bool> hasAttendance({
    required String studentId,
    required String driveId,
  });
}
