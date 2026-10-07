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

  final channel = Supabase.instance.client
      .channel('student_drives_realtime_${DateTime.now().millisecondsSinceEpoch}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'drives',
        callback: (_) {
          ref.invalidateSelf();
        },
      )
      .subscribe();

  ref.onDispose(() {
    Supabase.instance.client.removeChannel(channel);
  });

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

  // Realtime subscription: updates student applications on insert/update/delete immediately
  final channel = Supabase.instance.client
      .channel('student_apps_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'applications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'student_id',
          value: userId,
        ),
        callback: (_) {
          ref.invalidateSelf();
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
  });

  try {
    final response = await Supabase.instance.client
        .from('applications')
        .select('*, drive:drives(*, company:companies(*))')
        .eq('student_id', userId);

    return (response as List).map((map) => Application.fromMap(map)).toList();
  } catch (e) {
    try {
      final rawResponse = await Supabase.instance.client
          .from('applications')
          .select()
          .eq('student_id', userId);
      return (rawResponse as List).map((map) => Application.fromMap(map)).toList();
    } catch (_) {
      return [];
    }
  }
});

/// Set of drive IDs the current student has applied to.
/// Source of truth: Supabase `applications` table.
/// Uses Realtime subscription so the UI updates instantly on apply/withdraw.
final studentAppliedDriveIdsProvider = Provider<Set<String>>((ref) {
  final appsAsync = ref.watch(studentApplicationsProvider);
  return appsAsync.valueOrNull?.map((app) => app.driveId).toSet() ?? const {};
});
