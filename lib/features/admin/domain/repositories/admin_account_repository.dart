import '../../../../core/errors/failures.dart';

class UserRoleUpdateResult {
  final bool success;
  final Failure? failure;

  UserRoleUpdateResult({required this.success, this.failure});
}

abstract class AdminAccountRepository {
  Future<UserRoleUpdateResult> updateUserRole({
    required String targetUserId,
    required String newRole,
  });
}