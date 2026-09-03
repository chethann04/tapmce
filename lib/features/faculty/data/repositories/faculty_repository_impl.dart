import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/repositories/faculty_repository.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/models/paginated_response.dart';

import '../../../audit/domain/entities/audit_log_entry.dart';
import '../../../audit/domain/repositories/audit_log_repository.dart';
import '../../../../core/services/email_notification_service.dart';

class FacultyRepositoryImpl implements FacultyRepository {
  final SupabaseClient _supabase;
  final AuditLogRepository _auditLogRepo;
  final EmailNotificationService? _emailService;

  FacultyRepositoryImpl(this._supabase, this._auditLogRepo, [this._emailService]);

  @override
  Future<({PaginatedResponse<UserProfile>? data, Failure? failure})> getDepartmentStudents({
    required String department,
    required int page,
    required int limit,
  }) async {
    // Mock implementation for UI wiring
    return (data: PaginatedResponse<UserProfile>(items: [], totalCount: 0), failure: null);
  }

  @override
  Future<List<UserProfile>> getPendingStudents({required String department}) async {
    final cleanDept = department.trim();
    
    // First query: Fetch pending students for this faculty department
    var query = _supabase
        .from('profiles')
        .select()
        .eq('role', 'student')
        .eq('approval_status', 'pending');

    if (cleanDept.isNotEmpty) {
      query = query.ilike('department', '%$cleanDept%');
    }

    final response = await query.order('created_at', ascending: false);

    final list = (response as List)
        .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
        .toList();

    if (list.isNotEmpty) return list;

    // Fallback: If no match found by department substring, fetch all pending students so queue is never blocked
    final fallbackResponse = await _supabase
        .from('profiles')
        .select()
        .eq('role', 'student')
        .eq('approval_status', 'pending')
        .order('created_at', ascending: false);

    return (fallbackResponse as List)
        .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<UserProfile>> getVerifiedStudents({required String department}) async {
    final cleanDept = department.trim();
    var query = _supabase
        .from('profiles')
        .select()
        .eq('role', 'student')
        .eq('approval_status', 'approved');

    if (cleanDept.isNotEmpty) {
      query = query.ilike('department', '%$cleanDept%');
    }

    final response = await query.order('updated_at', ascending: false);
    final list = (response as List)
        .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
        .toList();

    if (list.isNotEmpty) return list;

    // Fallback: fetch all approved students if department name format differs
    final fallbackResponse = await _supabase
        .from('profiles')
        .select()
        .eq('role', 'student')
        .eq('approval_status', 'approved')
        .order('updated_at', ascending: false);

    return (fallbackResponse as List)
        .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<UserProfile>> getRejectedStudents({required String department}) async {
    final cleanDept = department.trim();
    var query = _supabase
        .from('profiles')
        .select()
        .eq('role', 'student')
        .eq('approval_status', 'rejected');

    if (cleanDept.isNotEmpty) {
      query = query.ilike('department', '%$cleanDept%');
    }

    final response = await query.order('updated_at', ascending: false);
    final list = (response as List)
        .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
        .toList();

    if (list.isNotEmpty) return list;

    final fallbackResponse = await _supabase
        .from('profiles')
        .select()
        .eq('role', 'student')
        .eq('approval_status', 'rejected')
        .order('updated_at', ascending: false);

    return (fallbackResponse as List)
        .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> reviewStudentApproval({
    required String studentId,
    required ApprovalStatus status,
    required String approvedBy,
    String? rejectionReason,
    String? verifiedCourseId,
    String? verifiedCourseCode,
    String? verifiedCourseName,
  }) async {
    final updateMap = <String, dynamic>{
      'approval_status': status.name,
      'approved_by': status == ApprovalStatus.approved ? approvedBy : null,
      'approved_at': status == ApprovalStatus.approved ? DateTime.now().toIso8601String() : null,
      'rejection_reason': rejectionReason,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (status == ApprovalStatus.approved) {
      updateMap['branch_verified'] = true;
      if (verifiedCourseCode != null && verifiedCourseCode.isNotEmpty) {
        updateMap['verified_course_id'] = verifiedCourseId;
        updateMap['verified_course_code'] = verifiedCourseCode;
        updateMap['verified_course_name'] = verifiedCourseName;
        updateMap['department'] = verifiedCourseName;
        updateMap['branch_source'] = 'faculty';
      }
    }

    await _supabase.from('profiles').update(updateMap).eq('id', studentId);
    
    await _auditLogRepo.logAction(
      action: status == ApprovalStatus.approved ? AuditAction.verification : AuditAction.rejection,
      description: status == ApprovalStatus.approved 
          ? 'Verified student profile ($studentId)${verifiedCourseCode != null ? ' with confirmed course $verifiedCourseCode ($verifiedCourseName)' : ''}.'
          : 'Rejected student profile ($studentId). Reason: $rejectionReason',
      targetId: studentId,
      targetTable: 'profiles',
    );

    // Non-blocking Email and In-App Notification Dispatch
    try {
      final studentData = await _supabase
          .from('profiles')
          .select('name, email, usn, department, verified_course_name, detected_course_name')
          .eq('id', studentId)
          .maybeSingle();

      if (studentData != null) {
        final email = studentData['email'] as String? ?? '';
        final name = studentData['name'] as String? ?? 'Student';
        final usn = studentData['usn'] as String? ?? '';
        final courseName = (studentData['verified_course_name'] ?? studentData['detected_course_name'] ?? studentData['department'] ?? 'UG Engineering') as String;

        // 1. Send Email
        if (email.isNotEmpty && _emailService != null) {
          if (status == ApprovalStatus.approved) {
            _emailService!.sendProfileApprovedEmail(
              recipientEmail: email,
              studentName: name,
              usn: usn,
              verifiedCourse: courseName,
            );
          } else if (status == ApprovalStatus.rejected) {
            _emailService!.sendProfileRejectedEmail(
              recipientEmail: email,
              studentName: name,
              reason: rejectionReason ?? 'Incorrect academic information. Please meet your coordinator.',
            );
          }
        }

        // 2. Insert In-App Notification linked to user_id
        await _supabase.from('notifications').insert({
          'recipient_id': studentId,
          'title': status == ApprovalStatus.approved ? 'Profile Approved' : 'Profile Verification Required',
          'message': status == ApprovalStatus.approved
              ? 'Your Placement Connect profile has been approved.'
              : 'Your profile requires correction: ${rejectionReason ?? "Please meet your Faculty Coordinator."}',
          'type': status == ApprovalStatus.approved ? 'profile_approved' : 'profile_rejected',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {
      // Non-blocking: failure in notification/email must not revert database approval
    }
  }

  @override
  Future<Map<String, dynamic>> getDepartmentPlacementStats({required String department}) async {
    final response = await _supabase
        .from('department_placement_stats')
        .select('*')
        .eq('department', department)
        .maybeSingle();

    return response ?? {
      'department': department,
      'total_students': 0,
      'total_placed': 0,
      'total_attended_any_drive': 0,
    };
  }

  @override
  Future<void> submitInterviewFeedback({
    required String applicationId,
    required String roundId,
    required String facultyId,
    required int rating,
    required String remarks,
    required bool recommend,
  }) async {
    await _supabase.from('interview_feedback').insert({
      'application_id': applicationId,
      'round_id': roundId,
      'faculty_id': facultyId,
      'rating': rating,
      'remarks': remarks,
      'recommend': recommend,
    });
  }
}