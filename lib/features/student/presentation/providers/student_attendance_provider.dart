import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/student_attendance_remote_datasource.dart';
import '../../data/repositories/student_attendance_repository_impl.dart';
import '../../domain/repositories/student_attendance_repository.dart';

final studentAttendanceDataSourceProvider = Provider<StudentAttendanceRemoteDataSource>((ref) {
  return StudentAttendanceRemoteDataSource(Supabase.instance.client);
});

final studentAttendanceRepositoryProvider = Provider<StudentAttendanceRepository>((ref) {
  return StudentAttendanceRepositoryImpl(ref.watch(studentAttendanceDataSourceProvider));
});

/// State for the attendance scanning flow.
enum ScanAttendanceStatus {
  idle,
  scanning,
  validating,
  success,
  error,
}

class ScanAttendanceState {
  final ScanAttendanceStatus status;
  final Map<String, dynamic>? attendanceRecord;
  final String? errorTitle;
  final String? errorMessage;

  const ScanAttendanceState({
    this.status = ScanAttendanceStatus.idle,
    this.attendanceRecord,
    this.errorTitle,
    this.errorMessage,
  });

  ScanAttendanceState copyWith({
    ScanAttendanceStatus? status,
    Map<String, dynamic>? attendanceRecord,
    String? errorTitle,
    String? errorMessage,
  }) {
    return ScanAttendanceState(
      status: status ?? this.status,
      attendanceRecord: attendanceRecord ?? this.attendanceRecord,
      errorTitle: errorTitle ?? this.errorTitle,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ScanAttendanceNotifier extends StateNotifier<ScanAttendanceState> {
  final StudentAttendanceRepository _repository;

  ScanAttendanceNotifier(this._repository) : super(const ScanAttendanceState());

  /// Process a scanned QR code payload.
  Future<void> processQrCode(String qrPayload) async {
    // Prevent duplicate processing
    if (state.status == ScanAttendanceStatus.validating) return;

    state = state.copyWith(status: ScanAttendanceStatus.validating);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = state.copyWith(
        status: ScanAttendanceStatus.error,
        errorTitle: 'Not Logged In',
        errorMessage: 'Please log in to mark attendance.',
      );
      return;
    }

    try {
      final record = await _repository.markAttendance(
        qrPayload: qrPayload,
        studentId: user.id,
      );

      state = state.copyWith(
        status: ScanAttendanceStatus.success,
        attendanceRecord: record,
      );
    } on AttendanceException catch (e) {
      state = state.copyWith(
        status: ScanAttendanceStatus.error,
        errorTitle: e.title,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: ScanAttendanceStatus.error,
        errorTitle: 'Something Went Wrong',
        errorMessage: 'Unable to mark attendance. Please try again later.',
      );
    }
  }

  /// Reset to scanning state (after error, allow re-scan).
  void resetToScanning() {
    state = state.copyWith(
      status: ScanAttendanceStatus.scanning,
      attendanceRecord: null,
      errorTitle: null,
      errorMessage: null,
    );
  }

  /// Reset to idle.
  void reset() {
    state = const ScanAttendanceState();
  }
}

final scanAttendanceProvider =
    StateNotifierProvider<ScanAttendanceNotifier, ScanAttendanceState>((ref) {
  return ScanAttendanceNotifier(ref.watch(studentAttendanceRepositoryProvider));
});
