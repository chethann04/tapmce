import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../domain/repositories/user_management_repository.dart';

import '../../../audit/domain/entities/audit_log_entry.dart';
import '../../../audit/domain/repositories/audit_log_repository.dart';

class UserManagementRepositoryImpl implements UserManagementRepository {
  final SupabaseClient _supabase;
  final AuditLogRepository _auditLogRepo;

  UserManagementRepositoryImpl(this._supabase, this._auditLogRepo);

  @override
  Future<void> appointTpo({
    required String email,
    required String appointedBy,
  }) async {

    // 1. Find profile by email (case-insensitive)
    final response = await _supabase
        .from('profiles')
        .select('id, name, role')
        .ilike('email', email)
        .maybeSingle();

    if (response == null) {
      throw Exception(
          'No user found with email: $email\n'
          'Make sure this person has signed up on the app first.');
    }

    final profileId = response['id'] as String?;
    final name = (response['name'] as String?) ?? 'Unknown';
    final currentRole = (response['role'] as String?) ?? 'student';

    if (profileId == null) {
      throw Exception('Profile has no valid ID.');
    }

    if (currentRole == 'tpo') {
      throw Exception('$name is already a TPO.');
    }

    if (currentRole == 'admin') {
      throw Exception('System Administrators ($name) cannot be appointed as TPO.');
    }

    if (currentRole == 'faculty_coordinator') {
      throw Exception(
          '$name is currently a Faculty Coordinator for a department. '
          'Reassign the department coordinator to someone else before appointing them as TPO.');
    }

    // 2. Use SECURITY DEFINER RPC to bypass RLS and update the role
    await _supabase.rpc('admin_set_user_role', params: {
      'p_profile_id': profileId,
      'p_role': 'tpo',
    });

    // 3. Insert into tpo_appointments (tracks history, upsert in case already exists)
    await _supabase.from('tpo_appointments').upsert({
      'profile_id': profileId,
      'appointed_by': appointedBy,
    }, onConflict: 'profile_id');

    // 4. Roles are exclusive: remove any previous coordinator appointment
    await _supabase
        .from('faculty_coordinators')
        .delete()
        .eq('profile_id', profileId);

    // 5. Log the audit action
    await _auditLogRepo.logAction(
      action: AuditAction.roleChange,
      targetTable: 'profiles',
      targetId: profileId,
      description: 'Appointed $name ($email) as TPO.',
    );
  }

  @override
  Future<void> appointFacultyCoordinator({
    required String email,
    required String department,
    required String appointedBy,
  }) async {

    // 1. Find profile by email (case-insensitive)
    final response = await _supabase
        .from('profiles')
        .select('id, name, role')
        .ilike('email', email)
        .maybeSingle();

    if (response == null) {
      throw Exception(
          'No user found with email: $email\n'
          'Make sure this person has signed up on the app first.');
    }

    final profileId = response['id'] as String?;
    final name = (response['name'] as String?) ?? 'Unknown';
    final currentRole = (response['role'] as String?) ?? 'student';

    if (profileId == null) {
      throw Exception('Profile has no valid ID.');
    }

    if (currentRole == 'admin') {
      throw Exception('System Administrators ($name) cannot be appointed as Faculty Coordinator.');
    }

    if (currentRole == 'tpo') {
      throw Exception('TPO Officer ($name) cannot be re-appointed as Faculty Coordinator.');
    }

    // 2. Set user role to faculty_coordinator and update department
    await _supabase.rpc('admin_set_user_role', params: {
      'p_profile_id': profileId,
      'p_role': 'faculty_coordinator',
    });

    await _supabase.from('profiles').update({
      'department': department,
    }).eq('id', profileId);

    // 3. Upsert into faculty_coordinators table
    await _supabase.from('faculty_coordinators').upsert({
      'profile_id': profileId,
      'department': department,
      'appointed_by': appointedBy,
    }, onConflict: 'profile_id');

    // 4. Roles are exclusive: remove any previous TPO appointment
    await _supabase
        .from('tpo_appointments')
        .delete()
        .eq('profile_id', profileId);

    // 5. Log audit action
    await _auditLogRepo.logAction(
      action: AuditAction.roleChange,
      targetTable: 'profiles',
      targetId: profileId,
      description: 'Appointed $name ($email) as Faculty Coordinator for $department.',
    );
  }

  @override
  Future<List<UserProfile>> getTpoList() async {
    // Source of truth is profiles.role, NOT the tpo_appointments table.
    // This prevents demoted/promoted coordinators from lingering as TPOs.
    final response = await _supabase
        .from('profiles')
        .select('*')
        .eq('role', 'tpo');

    return (response as List)
        .map((map) => UserProfile.fromMap(map))
        .toList();
  }

  @override
  Future<void> createAcademicCycle({
    required String academicYear,
    required String eligibleBatch,
    required List<String> branches,
    required String createdBy,
  }) async {
    await _supabase.from('academic_cycles').insert({
      'academic_year': academicYear,
      'eligible_batch': eligibleBatch,
      'branches': branches,
      'created_by': createdBy,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getAcademicCycles() async {
    final response = await _supabase.from('academic_cycles').select('*');
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> getNaacInstitutionReport() async {
    final response = await _supabase
        .from('department_placement_stats')
        .select('*');
    return List<Map<String, dynamic>>.from(response);
  }
}