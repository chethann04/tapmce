import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/faculty_repository_impl.dart';
import '../../domain/repositories/faculty_repository.dart';
import '../../../audit/domain/repositories/audit_log_repository.dart';

import '../../../../core/services/email_notification_service.dart';

final facultyRepositoryProvider = Provider<FacultyRepository>((ref) {
  final auditRepo = ref.watch(auditLogRepositoryProvider);
  final emailService = ref.watch(emailNotificationServiceProvider);
  return FacultyRepositoryImpl(Supabase.instance.client, auditRepo, emailService);
});

/// Resolves faculty department with multi-layer fallback so the dashboard never renders blank.
Future<String> _resolveFacultyDepartment(Ref ref) async {
  final userProfile = ref.watch(authNotifierProvider).value;
  if (userProfile?.department != null && userProfile!.department!.isNotEmpty) {
    return userProfile.department!;
  }

  // Fallback 1: Read user metadata
  final user = Supabase.instance.client.auth.currentUser;
  final metaDept = user?.userMetadata?['department'] as String?;
  if (metaDept != null && metaDept.isNotEmpty) {
    return metaDept;
  }

  // Fallback 2: Check faculty_coordinators table
  if (user != null) {
    try {
      final coord = await Supabase.instance.client
          .from('faculty_coordinators')
          .select('department')
          .eq('profile_id', user.id)
          .maybeSingle();
      if (coord != null && coord['department'] != null) {
        final dept = coord['department'] as String;
        if (dept.isNotEmpty) return dept;
      }
    } catch (_) {}
  }

  return '';
}

final pendingStudentsProvider = FutureProvider<List<UserProfile>>((ref) async {
  final department = await _resolveFacultyDepartment(ref);
  final repo = ref.watch(facultyRepositoryProvider);

  // If department is still empty, fetch ALL pending students across departments
  if (department.isEmpty) {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('*')
        .eq('role', 'student')
        .eq('approval_status', 'pending')
        .order('created_at', ascending: false);
    return (response as List).map((map) => UserProfile.fromMap(map)).toList();
  }

  return repo.getPendingStudents(department: department);
});

final verifiedStudentsProvider = FutureProvider<List<UserProfile>>((ref) async {
  final department = await _resolveFacultyDepartment(ref);
  final repo = ref.watch(facultyRepositoryProvider);

  if (department.isEmpty) {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('*')
        .eq('role', 'student')
        .eq('approval_status', 'approved')
        .order('name', ascending: true);
    return (response as List).map((map) => UserProfile.fromMap(map)).toList();
  }

  return repo.getVerifiedStudents(department: department);
});

final rejectedStudentsProvider = FutureProvider<List<UserProfile>>((ref) async {
  final department = await _resolveFacultyDepartment(ref);
  final repo = ref.watch(facultyRepositoryProvider);

  if (department.isEmpty) {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('*')
        .eq('role', 'student')
        .eq('approval_status', 'rejected')
        .order('name', ascending: true);
    return (response as List).map((map) => UserProfile.fromMap(map)).toList();
  }

  return repo.getRejectedStudents(department: department);
});

final deptPlacementStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final department = await _resolveFacultyDepartment(ref);
  final repo = ref.watch(facultyRepositoryProvider);
  if (department.isEmpty) return {'total_students': 0, 'total_placed': 0};

  return repo.getDepartmentPlacementStats(department: department);
});