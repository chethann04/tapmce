import '../entities/auth_state.dart';
import '../entities/user_profile.dart';

abstract class AuthRepository {
  Future<AuthState> getInitialAuthState();
  Future<AuthState> signIn({required String email, required String password});
  Future<AuthState> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  });
  Future<AuthState> verifyOtp({
    required String email,
    required String otpToken,
    required String fullName,
    required UserRole role,
  });
  Future<void> signOut(String userId);
  Future<UserProfile?> fetchProfile(String userId);
}
