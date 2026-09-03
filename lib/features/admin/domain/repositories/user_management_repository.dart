import '../../../auth/domain/entities/user_profile.dart';

abstract class UserManagementRepository {
  Future<void> appointTpo({
    required String email,
    required String appointedBy,
  });

  Future<void> appointFacultyCoordinator({
    required String email,
    required String department,
    required String appointedBy,
  });

  Future<List<UserProfile>> getTpoList();

  Future<void> createAcademicCycle({
    required String academicYear,
    required String eligibleBatch,
    required List<String> branches,
    required String createdBy,
  });

  Future<List<Map<String, dynamic>>> getAcademicCycles();

  Future<List<Map<String, dynamic>>> getNaacInstitutionReport();
}