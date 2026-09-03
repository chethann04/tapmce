import '../../domain/entities/student_onboarding_data.dart';
import '../../domain/repositories/student_profile_repository.dart';
import '../datasources/student_profile_remote_datasource.dart';

class StudentProfileRepositoryImpl implements StudentProfileRepository {
  final StudentProfileRemoteDatasource _datasource;

  StudentProfileRepositoryImpl(this._datasource);

  @override
  Future<void> saveOnboardingProfile({
    required String userId,
    required StudentOnboardingData data,
  }) async {
    String? resumeUrl = data.existingResumeUrl;
    String? photoUrl = data.existingPhotoUrl;

    // Upload resume if new bytes provided
    if (data.resumeBytes != null && data.resumeFileName != null) {
      resumeUrl = await _datasource.uploadResume(
        userId: userId,
        bytes: data.resumeBytes!,
        fileName: data.resumeFileName!,
      );
    }

    // Upload photo if new bytes provided
    if (data.photoBytes != null && data.photoFileName != null) {
      photoUrl = await _datasource.uploadPhoto(
        userId: userId,
        bytes: data.photoBytes!,
        fileName: data.photoFileName!,
      );
    }

    await _datasource.saveOnboardingProfile(
      userId: userId,
      data: data,
      resumeUrl: resumeUrl,
      photoUrl: photoUrl,
    );
  }
}
