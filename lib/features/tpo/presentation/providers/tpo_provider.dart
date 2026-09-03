import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/domain/entities/company.dart';
import '../../../student/domain/entities/drive.dart';
import '../../data/repositories/tpo_repository_impl.dart';
import '../../domain/repositories/tpo_repository.dart';
import '../../domain/entities/drive_round.dart';
import '../../../audit/domain/repositories/audit_log_repository.dart';
import '../../../../core/services/email_notification_service.dart';

final tpoRepositoryProvider = Provider<TpoRepository>((ref) {
  final auditRepo = ref.watch(auditLogRepositoryProvider);
  final emailService = ref.watch(emailNotificationServiceProvider);
  return TpoRepositoryImpl(Supabase.instance.client, auditRepo, emailService);
});

final tpoDrivesProvider = FutureProvider<List<Drive>>((ref) async {
  final repo = ref.watch(tpoRepositoryProvider);
  return repo.getDrives();
});

final tpoCompaniesProvider = FutureProvider<List<Company>>((ref) async {
  final repo = ref.watch(tpoRepositoryProvider);
  return repo.getCompanies();
});

final facultyCoordinatorsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(tpoRepositoryProvider);
  return repo.fetchFacultyCoordinators();
});

final driveAttendanceProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, driveId) async {
  final repo = ref.watch(tpoRepositoryProvider);
  return repo.fetchDriveAttendance(driveId);
});

/// Total applicant count across all drives.
final tpoApplicantCountProvider = FutureProvider<int>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('applications')
        .select('id');
    return (response as List).length;
  } catch (_) {
    return 0;
  }
});

/// Total offers count (status = 'selected') across all drives.
final tpoOffersCountProvider = FutureProvider<int>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('applications')
        .select('id')
        .eq('status', 'selected');
    return (response as List).length;
  } catch (_) {
    return 0;
  }
});

/// Applicant count per drive - returns Map<driveId, count>.
final tpoDriveApplicantCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('applications')
        .select('drive_id');

    final map = <String, int>{};
    for (final row in response as List) {
      final driveId = row['drive_id'] as String?;
      if (driveId != null) {
        map[driveId] = (map[driveId] ?? 0) + 1;
      }
    }
    return map;
  } catch (_) {
    return {};
  }
});

/// List of students who applied to a specific drive.
final tpoDriveApplicantsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, driveId) async {
  final response = await Supabase.instance.client
      .from('applications')
      .select('id, status, applied_at, student_id, student:profiles!applications_student_id_fkey(name, email, usn, department, cgpa, semester)')
      .eq('drive_id', driveId)
      .order('applied_at', ascending: false);

  return (response as List).cast<Map<String, dynamic>>();
});

/// Rounds for a specific drive.
final driveRoundsProvider = FutureProvider.family<List<DriveRound>, String>((ref, driveId) async {
  final repo = ref.watch(tpoRepositoryProvider);
  return repo.getDriveRounds(driveId);
});

/// Students in a specific round of a drive.
final roundStudentsProvider = FutureProvider.family<List<Map<String, dynamic>>, ({String driveId, int roundNumber})>((ref, params) async {
  final repo = ref.watch(tpoRepositoryProvider);
  return repo.getRoundStudents(driveId: params.driveId, roundNumber: params.roundNumber);
});

/// Student's round progress for a specific application.
final studentRoundProgressProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, applicationId) async {
  final repo = ref.watch(tpoRepositoryProvider);
  return repo.getStudentRoundProgress(applicationId);
});
