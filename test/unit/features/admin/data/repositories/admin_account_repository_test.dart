import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:placement_connect/core/errors/exceptions.dart';
import 'package:placement_connect/core/errors/failures.dart';
import 'package:placement_connect/features/admin/data/datasources/admin_account_remote_datasource.dart';
import 'package:placement_connect/features/admin/data/repositories/admin_account_repository_impl.dart';

class MockAdminAccountRemoteDatasource extends Mock implements AdminAccountRemoteDatasource {}

void main() {
  late AdminAccountRepositoryImpl repository;
  late MockAdminAccountRemoteDatasource mockDatasource;

  setUp(() {
    mockDatasource = MockAdminAccountRemoteDatasource();
    repository = AdminAccountRepositoryImpl(remoteDatasource: mockDatasource);
  });

  group('updateUserRole', () {
    const tUserId = '123';
    const tNewRole = 'tpo';

    test('returns success true when datasource updates successfully', () async {
      when(() => mockDatasource.updateRole(userId: tUserId, role: tNewRole))
          .thenAnswer((_) async {});

      final result = await repository.updateUserRole(targetUserId: tUserId, newRole: tNewRole);

      expect(result.success, true);
      expect(result.failure, isNull);
      verify(() => mockDatasource.updateRole(userId: tUserId, role: tNewRole)).called(1);
      verifyNoMoreInteractions(mockDatasource);
    });

    test('returns ServerFailure when datasource throws ServerException', () async {
      when(() => mockDatasource.updateRole(userId: tUserId, role: tNewRole))
          .thenThrow(const ServerException('Rate limit exceeded', code: '429'));

      final result = await repository.updateUserRole(targetUserId: tUserId, newRole: tNewRole);

      expect(result.success, false);
      expect(result.failure, isA<ServerFailure>());
      final failure = result.failure as ServerFailure;
      expect(failure.code, '429');
    });
  });
}
