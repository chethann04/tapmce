import '../../../../core/errors/failures.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

class VerifyOtpUseCase {
  final AuthRepository repository;
  final SecureStorageService secureStorage;

  VerifyOtpUseCase({required this.repository, required this.secureStorage});

  Future<({AuthState state, Failure? failure})> call({
    required String email,
    required String otpToken,
  }) async {
    // Retrieve the temporarily stored metadata
    final roleStr = await secureStorage.read('pending_signup_role');
    final name = await secureStorage.read('pending_signup_name');

    if (roleStr == null || name == null) {
      // Fallback if secure storage was cleared unexpectedly
      return (
        state: const AuthState.unauthenticated(),
        failure: const Failure.auth(message: 'Signup session expired. Please try again.')
      );
    }

    final role = UserRole.values.byName(roleStr);

    final result = await repository.verifyOtp(
      email: email,
      otpToken: otpToken,
      fullName: name,
      role: role,
    );

    // Clean up secure storage on success or failure
    await secureStorage.delete('pending_signup_role');
    await secureStorage.delete('pending_signup_name');

    return (state: result, failure: null);
  }
}