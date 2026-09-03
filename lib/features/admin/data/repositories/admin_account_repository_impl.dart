import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/repositories/admin_account_repository.dart';
import '../datasources/admin_account_remote_datasource.dart';

class AdminAccountRepositoryImpl implements AdminAccountRepository {
  final AdminAccountRemoteDatasource remoteDatasource;

  AdminAccountRepositoryImpl({required this.remoteDatasource});

  @override
  Future<UserRoleUpdateResult> updateUserRole({
    required String targetUserId,
    required String newRole,
  }) async {
    try {
      await remoteDatasource.updateRole(userId: targetUserId, role: newRole);
      return UserRoleUpdateResult(success: true);
    } on ServerException catch (e) {
      return UserRoleUpdateResult(
        success: false,
        failure: ServerFailure(message: e.message, code: e.code),
      );
    } catch (e) {
      return UserRoleUpdateResult(
        success: false,
        failure: ServerFailure(message: e.toString()),
      );
    }
  }
}