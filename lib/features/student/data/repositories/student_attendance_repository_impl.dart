import '../../domain/repositories/student_attendance_repository.dart';
import '../datasources/student_attendance_remote_datasource.dart';

class StudentAttendanceRepositoryImpl implements StudentAttendanceRepository {
  final StudentAttendanceRemoteDataSource _dataSource;

  StudentAttendanceRepositoryImpl(this._dataSource);

  @override
  Future<Map<String, dynamic>> markAttendance({
    required String qrPayload,
    required String studentId,
  }) {
    return _dataSource.markAttendance(
      qrPayload: qrPayload,
      studentId: studentId,
    );
  }

  @override
  Future<bool> hasAttendance({
    required String studentId,
    required String driveId,
  }) {
    return _dataSource.hasAttendance(
      studentId: studentId,
      driveId: driveId,
    );
  }
}
