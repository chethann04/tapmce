import '../entities/student_onboarding_data.dart';

/// Repository contract for saving and loading the student's onboarding profile.
abstract class StudentProfileRepository {
  /// Saves all wizard data to Supabase and marks `profile_completed = true`.
  Future<void> saveOnboardingProfile({
    required String userId,
    required StudentOnboardingData data,
  });
}
