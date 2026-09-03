import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/student_profile_remote_datasource.dart';
import '../../data/repositories/student_profile_repository_impl.dart';
import '../../domain/entities/student_onboarding_data.dart';
import '../../domain/repositories/student_profile_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── Datasource provider ────────────────────────────────────────────────────
final studentProfileDatasourceProvider =
    Provider<StudentProfileRemoteDatasource>((ref) {
  return StudentProfileRemoteDatasource(Supabase.instance.client);
});

// ── Repository provider ────────────────────────────────────────────────────
final studentProfileRepositoryProvider =
    Provider<StudentProfileRepository>((ref) {
  return StudentProfileRepositoryImpl(
    ref.watch(studentProfileDatasourceProvider),
  );
});

// ── Onboarding Notifier ────────────────────────────────────────────────────

class StudentOnboardingNotifier
    extends StateNotifier<AsyncValue<void>> {
  final StudentProfileRepository _repository;
  final Ref _ref;

  StudentOnboardingNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Submits wizard data. On success refreshes the auth profile so the router
  /// redirects to the student dashboard automatically.
  Future<bool> submit({
    required String userId,
    required StudentOnboardingData data,
    bool refreshAuth = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.saveOnboardingProfile(
        userId: userId,
        data: data,
      );
      if (refreshAuth) {
        // Invalidate auth provider so profileCompleted = true is picked up
        _ref.invalidate(authNotifierProvider);
      }
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final studentOnboardingNotifierProvider =
    StateNotifierProvider<StudentOnboardingNotifier, AsyncValue<void>>((ref) {
  return StudentOnboardingNotifier(
    ref.watch(studentProfileRepositoryProvider),
    ref,
  );
});
