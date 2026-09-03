import '../../../../core/errors/failures.dart';
import '../../../../shared/models/paginated_response.dart';
import '../../../auth/domain/entities/user_profile.dart';

abstract class FacultyRepository {
  Future<({PaginatedResponse<UserProfile>? data, Failure? failure})> getDepartmentStudents({
    required String department,
    required int page,
    required int limit,
  });

  Future<List<UserProfile>> getPendingStudents({required String department});

  Future<List<UserProfile>> getVerifiedStudents({required String department});

  Future<List<UserProfile>> getRejectedStudents({required String department});

  Future<void> reviewStudentApproval({
    required String studentId,
    required ApprovalStatus status,
    required String approvedBy,
    String? rejectionReason,
    String? verifiedCourseId,
    String? verifiedCourseCode,
    String? verifiedCourseName,
  });

  Future<Map<String, dynamic>> getDepartmentPlacementStats({required String department});

  Future<void> submitInterviewFeedback({
    required String applicationId,
    required String roundId,
    required String facultyId,
    required int rating,
    required String remarks,
    required bool recommend,
  });
}