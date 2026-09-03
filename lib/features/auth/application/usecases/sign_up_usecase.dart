import '../../../../core/errors/failures.dart';
import '../../../../core/security/secure_storage_service.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

class SignUpUseCase {
  final AuthRepository repository;
  final SecureStorageService secureStorage;

  SignUpUseCase({required this.repository, required this.secureStorage});

  Future<({AuthState state, Failure? failure})> call({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  }) async {
    // Temporarily store role and name securely so the OTP step can use them
    await secureStorage.write('pending_signup_role', role.name);
    await secureStorage.write('pending_signup_name', fullName);

    return repository.signUp(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
    ).then((state) => (state: state, failure: null));
  }
}