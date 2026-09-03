import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/drive.dart';
import '../../domain/entities/application.dart';
import '../../data/repositories/student_drive_repository_impl.dart';
import '../../data/datasources/student_drive_remote_datasource.dart';

final studentDriveRepositoryProvider = Provider((ref) {
  final dataSource = StudentDriveRemoteDataSourceImpl(Supabase.instance.client);
  return StudentDriveRepositoryImpl(remoteDataSource: dataSource);
});

final studentEligibleDrivesProvider = FutureProvider<List<Drive>>((ref) async {
  final repo = ref.watch(studentDriveRepositoryProvider);
  try {
    return await repo.getEligibleDrives();
  } catch (e) {
    return [];
  }
});

final studentApplicationsProvider = FutureProvider<List<Application>>((ref) async {
  final authProfile = ref.watch(authNotifierProvider).valueOrNull;
  final userId = Supabase.instance.client.auth.currentUser?.id ?? authProfile?.id;
  if (userId == null || userId.isEmpty) return [];

  try {
    final response = await Supabase.instance.client
        .from('applications')
        .select('*, drive:drives(*, company:companies(*))')
        .eq('student_id', userId);

    return (response as List).map((map) => Application.fromMap(map)).toList();
  } catch (e) {
    return [];
  }
});

/// Set of drive IDs the current student has applied to.
/// Source of truth: Supabase `applications` table.
/// Uses Realtime subscription so the UI updates instantly on apply/withdraw.
final studentAppliedDriveIdsProvider = Provider<Set<String>>((ref) {
  final appsAsync = ref.watch(studentApplicationsProvider);
  return appsAsync.valueOrNull?.map((app) => app.driveId).toSet() ?? const {};
});
