import '../../../../shared/domain/entities/company.dart';
import '../../../student/domain/entities/drive.dart';
import '../../../student/domain/entities/application.dart';
import '../entities/drive_round.dart';

abstract class TpoRepository {
  Future<void> appointFacultyCoordinator({
    required String profileId,
    required String department,
    required String appointedBy,
  });

  Future<List<Map<String, dynamic>>> fetchFacultyCoordinators();

  Future<void> createCompany({
    required String name,
    String? industry,
    String? hrContactName,
    String? hrContactEmail,
    String? hrContactPhone,
    required String createdBy,
  });

  Future<List<Company>> getCompanies();

  Future<String> createDrive({
    required String companyId,
    required String roleTitle,
    String? ctcOrStipend,
    String? jobDescription,
    List<String>? eligibilityBranches,
    double? cgpaCutoff,
    int? backlogLimit,
    DateTime? applicationDeadline,
    required String status,
    required String createdBy,
  });

  Future<void> updateCompany({
    required String companyId,
    required String name,
  });

  Future<List<Drive>> getDrives();

  Future<void> updateDriveStatus({
    required String driveId,
    required String status,
  });

  Future<void> updateDrive({
    required String driveId,
    String? companyId,
    required String roleTitle,
    String? ctcOrStipend,
    String? jobDescription,
    List<String>? eligibilityBranches,
    double? cgpaCutoff,
    int? backlogLimit,
    DateTime? applicationDeadline,
  });

  Future<void> updateApplicationStatus({
    required String applicationId,
    required ApplicationStatus status,
  });

  Future<void> bulkUpdateShortlist({
    required String driveId,
    required List<String> studentIds,
    required ApplicationStatus status,
  });

  Future<void> uploadOffer({
    required String applicationId,
    required double ctc,
    required String offerLetterUrl,
    required DateTime joiningDate,
  });

  Future<List<Map<String, dynamic>>> fetchDriveAttendance(String driveId);

  // ── Round Management ──────────────────────────────────────────────────

  Future<void> saveDriveRounds({
    required String driveId,
    required List<String> roundNames,
    required String createdBy,
  });

  Future<List<DriveRound>> getDriveRounds(String driveId);

  Future<List<Map<String, dynamic>>> getRoundStudents({
    required String driveId,
    required int roundNumber,
  });

  Future<void> moveStudentsToNextRound({
    required String driveId,
    required int currentRoundNumber,
    required List<String> applicationIds,
    required String performedBy,
  });

  Future<void> rejectStudents({
    required String driveId,
    required int currentRoundNumber,
    required List<String> applicationIds,
    String? remarks,
    required String performedBy,
  });

  Future<void> markStudentsAbsent({
    required String driveId,
    required int currentRoundNumber,
    required List<String> applicationIds,
    required String performedBy,
  });

  Future<void> addRoundRemarks({
    required String applicationId,
    required String roundId,
    required String remarks,
    required String performedBy,
  });

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? driveId,
    String? applicationId,
  });

  Future<List<Map<String, dynamic>>> getStudentRoundProgress(String applicationId);
}