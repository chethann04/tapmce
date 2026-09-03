import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/user_management_repository_impl.dart';
import '../../domain/repositories/user_management_repository.dart';
import '../../../audit/domain/repositories/audit_log_repository.dart';

final userManagementRepositoryProvider = Provider<UserManagementRepository>((ref) {
  return UserManagementRepositoryImpl(
    Supabase.instance.client,
    ref.watch(auditLogRepositoryProvider),
  );
});

/// Fetches registered profiles with role='faculty' so admin can appoint them.
final facultyListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await Supabase.instance.client
      .from('profiles')
      .select('id, name, email, department, role')
      .eq('role', 'faculty')
      .order('name', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});

/// Fetches real-time counts for Users, Companies, and Audit Logs.
final adminStatsProvider =
    FutureProvider<({int userCount, int companyCount, int auditLogCount})>((ref) async {
  final client = Supabase.instance.client;
  final usersRes = await client.from('profiles').select('id');
  final companiesRes = await client.from('companies').select('id');
  final auditRes = await client.from('audit_logs').select('id');
  return (
    userCount: (usersRes as List).length,
    companyCount: (companiesRes as List).length,
    auditLogCount: (auditRes as List).length,
  );
});

/// FULLY DYNAMIC NAAC/NBA Compliance Reports.
/// Aggregates real data from:
///  - profiles (role='student')           → total_students per department
///  - applications (student_id, drive_id) → total_attended per department
///  - applications (status=selected/offered) → total_placed per department
///
/// NOTE: Does NOT depend on `is_placed` column (not in schema).
final complianceReportsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;

  // 1. Fetch all student profiles — only columns that exist in schema
  final profilesRes = await client
      .from('profiles')
      .select('id, department')
      .eq('role', 'student');

  final profiles = List<Map<String, dynamic>>.from(profilesRes);

  // Build studentId → department lookup
  final Map<String, String> studentDeptMap = {};
  for (final p in profiles) {
    final id = p['id']?.toString();
    final dept = (p['department'] as String?)?.trim();
    if (id != null && dept != null && dept.isNotEmpty) {
      studentDeptMap[id] = dept;
    }
  }

  // 2. Fetch all applications (student_id, drive_id, status)
  List<Map<String, dynamic>> applications = [];
  try {
    final applicationsRes = await client
        .from('applications')
        .select('student_id, drive_id, status');
    applications = List<Map<String, dynamic>>.from(applicationsRes);
  } catch (_) {
    // applications table may be empty or restricted — continue with profile-only data
  }

  // Count unique drives attended per department
  final Map<String, Set<String>> deptAttendedSet = {};
  // Count placed students (selected/offered) per department
  final Map<String, Set<String>> deptPlacedSet = {};

  for (final app in applications) {
    final studentId = app['student_id']?.toString();
    final driveId = app['drive_id']?.toString();
    final status = app['status']?.toString();
    if (studentId == null || driveId == null) continue;

    final dept = studentDeptMap[studentId];
    if (dept == null) continue;

    // Count each unique student+drive combination as "attended"
    deptAttendedSet.putIfAbsent(dept, () => <String>{});
    deptAttendedSet[dept]!.add('$studentId:$driveId');

    // Placed = selected or offered
    if (status == 'selected' || status == 'offered') {
      deptPlacedSet.putIfAbsent(dept, () => <String>{});
      deptPlacedSet[dept]!.add(studentId);
    }
  }

  // 3. Build per-department stats
  final Map<String, Map<String, dynamic>> deptStats = {};

  for (final p in profiles) {
    final dept = (p['department'] as String?)?.trim();
    if (dept == null || dept.isEmpty) continue;

    deptStats.putIfAbsent(dept, () => {
      'department': dept,
      'total_students': 0,
      'total_placed': 0,
      'total_attended': 0,
    });
    deptStats[dept]!['total_students'] =
        (deptStats[dept]!['total_students'] as int) + 1;
  }

  // Fill placed & attended from application records
  for (final dept in deptStats.keys) {
    deptStats[dept]!['total_attended'] =
        deptAttendedSet[dept]?.length ?? 0;
    deptStats[dept]!['total_placed'] =
        deptPlacedSet[dept]?.length ?? 0;
  }

  final result = deptStats.values.toList()
    ..sort((a, b) =>
        (a['department'] as String).compareTo(b['department'] as String));

  return result;
});

/// Institute-level summary for compliance report header.
final complianceSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final stats = await ref.watch(complianceReportsProvider.future);
  final client = Supabase.instance.client;

  int totalDrives = 0;
  int totalCompanies = 0;

  try {
    final drivesRes = await client.from('drives').select('id');
    totalDrives = (drivesRes as List).length;
  } catch (_) {}

  try {
    final companiesRes = await client.from('companies').select('id');
    totalCompanies = (companiesRes as List).length;
  } catch (_) {}

  int totalStudents = 0, totalPlaced = 0, totalAttended = 0;
  for (final s in stats) {
    totalStudents += (s['total_students'] as int? ?? 0);
    totalPlaced += (s['total_placed'] as int? ?? 0);
    totalAttended += (s['total_attended'] as int? ?? 0);
  }

  return {
    'total_students': totalStudents,
    'total_placed': totalPlaced,
    'total_attended': totalAttended,
    'total_drives': totalDrives,
    'total_companies': totalCompanies,
    'placement_percentage': totalStudents > 0
        ? ((totalPlaced / totalStudents) * 100).toStringAsFixed(1)
        : '0.0',
  };
});
