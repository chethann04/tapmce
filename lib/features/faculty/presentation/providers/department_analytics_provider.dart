import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Per-query result wrapper — captures data OR the exact error
// ─────────────────────────────────────────────────────────────────────────────
class _QueryResult {
  final String queryName;
  final List<dynamic> rows;
  final Object? error;
  final StackTrace? stackTrace;

  const _QueryResult({
    required this.queryName,
    this.rows = const [],
    this.error,
    this.stackTrace,
  });

  bool get failed => error != null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Safe per-query executor
// ─────────────────────────────────────────────────────────────────────────────
Future<_QueryResult> _runQuery(
    String name, Future<dynamic> Function() fn) async {
  try {
    final data = await fn();
    final rows = data as List? ?? [];
    if (kDebugMode) {
      dev.log('[Analytics:$name] OK — ${rows.length} rows');
    }
    return _QueryResult(queryName: name, rows: rows);
  } on PostgrestException catch (e, st) {
    // Log the EXACT Postgrest exception, not a masked message
    dev.log(
      '[Analytics:$name] PostgrestException:\n'
      '  message : ${e.message}\n'
      '  code    : ${e.code}\n'
      '  details : ${e.details}\n'
      '  hint    : ${e.hint}',
      error: e,
      stackTrace: st,
    );
    return _QueryResult(queryName: name, error: e, stackTrace: st);
  } catch (e, st) {
    dev.log('[Analytics:$name] Unexpected error: $e',
        error: e, stackTrace: st);
    return _QueryResult(queryName: name, error: e, stackTrace: st);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class DepartmentAnalyticsData {
  final String department;

  // Section 1 — Overview
  final int eligibleStudents;
  final int appliedStudents;
  final int offersReceived;
  final double placementPercentage;

  // Section 2 — Recruitment funnel
  final List<String> roundNames;
  final List<int> funnelCounts;

  // Section 3 — Drive performance
  final List<DriveAnalytics> drives;

  // Section 4 — Placement status donut
  final int selectedCount;
  final int inProcessCount;
  final int rejectedCount;
  final int notAppliedCount;

  // Section 5 — Round performance
  final List<RoundPerformance> roundPerformance;

  // Section 6 — Students needing attention
  final int profileIncomplete;
  final int resumeMissing;
  final List<String> resumeMissingStudentNames;
  final int attendanceNotMarked;
  final int eligibleButNotApplied;
  final int documentsPending;

  // Section 7 — Quick insights
  final String highestAppliedDrive;
  final String highestPackageDrive;
  final String lowestParticipationDrive;
  final double avgCgpa;
  final double departmentApplicationRate;
  final double offerConversionRate;
  final double attendancePercentage;

  // Per-widget errors for graceful degradation
  final Map<String, String> queryErrors;

  const DepartmentAnalyticsData({
    required this.department,
    this.eligibleStudents = 0,
    this.appliedStudents = 0,
    this.offersReceived = 0,
    this.placementPercentage = 0,
    this.roundNames = const [],
    this.funnelCounts = const [],
    this.drives = const [],
    this.selectedCount = 0,
    this.inProcessCount = 0,
    this.rejectedCount = 0,
    this.notAppliedCount = 0,
    this.roundPerformance = const [],
    this.profileIncomplete = 0,
    this.resumeMissing = 0,
    this.resumeMissingStudentNames = const [],
    this.attendanceNotMarked = 0,
    this.eligibleButNotApplied = 0,
    this.documentsPending = 0,
    this.highestAppliedDrive = '—',
    this.highestPackageDrive = '—',
    this.lowestParticipationDrive = '—',
    this.avgCgpa = 0,
    this.departmentApplicationRate = 0,
    this.offerConversionRate = 0,
    this.attendancePercentage = 0,
    this.queryErrors = const {},
  });

  /// True if any individual query failed — page still shows partial data.
  bool get hasPartialErrors => queryErrors.isNotEmpty;
}

class DriveAnalytics {
  final String driveId;
  final String companyName;
  final String role;
  final String status;
  final DateTime? deadline;
  final int applied;
  final int attendance;
  final int qualified;
  final int rejected;
  final int selected;
  final double selectionPercent;
  final List<RoundAnalytics> rounds;

  const DriveAnalytics({
    required this.driveId,
    required this.companyName,
    required this.role,
    required this.status,
    this.deadline,
    this.applied = 0,
    this.attendance = 0,
    this.qualified = 0,
    this.rejected = 0,
    this.selected = 0,
    this.selectionPercent = 0,
    this.rounds = const [],
  });
}

class RoundAnalytics {
  final String roundName;
  final int entered;
  final int qualified;

  const RoundAnalytics({
    required this.roundName,
    this.entered = 0,
    this.qualified = 0,
  });
}

class RoundPerformance {
  final String roundName;
  final int qualified;
  final int rejected;
  final double passPercentage;

  const RoundPerformance({
    required this.roundName,
    this.qualified = 0,
    this.rejected = 0,
    this.passPercentage = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Main fetch function — each query is independent
// ─────────────────────────────────────────────────────────────────────────────
Future<DepartmentAnalyticsData> fetchDepartmentAnalytics(
    String department) async {
  final client = Supabase.instance.client;

  // ── 1. Eligible students (approved students in this department) ─────
  // Columns confirmed: id, cgpa, resume_url, photo_url, id_proof_url,
  //                    profile_completed (added in 00013)
  final q1 = await _runQuery('profiles', () => client
      .from('profiles')
      .select('id, name, usn, cgpa, resume_url, photo_url, profile_completed')
      .eq('department', department)
      .eq('role', 'student')
      .eq('approval_status', 'approved'));

  // ── 2. Drives with company info ─────────────────────────────────────
  // Columns confirmed: id, role, role_title, status, end_date, package_lpa
  // FK column: company_id → companies(id, name)
  // PostgREST alias: companies!company_id(id,name) avoids ambiguity
  final q2 = await _runQuery('drives', () => client.from('drives').select(
      'id, role, role_title, status, end_date, package_lpa, '
      'companies!company_id(id, name)'));

  // ── 3. Applications (all — filter by eligibleStudentIds in compute) ─
  // Columns confirmed: id, drive_id, student_id, status, current_round,
  //                    applied_at
  final q3 = await _runQuery(
      'applications',
      () => client
          .from('applications')
          .select('id, drive_id, student_id, status, current_round, applied_at'));

  // ── 4. Drive attendance ─────────────────────────────────────────────
  // Columns confirmed: drive_id, student_id, status, scanned_at
  final q4 = await _runQuery(
      'drive_attendance',
      () => client
          .from('drive_attendance')
          .select('drive_id, student_id, status, scanned_at'));

  // ── 5. Drive rounds ─────────────────────────────────────────────────
  // Columns confirmed: id, drive_id, round_number, round_name
  final q5 = await _runQuery(
      'drive_rounds',
      () => client
          .from('drive_rounds')
          .select('id, drive_id, round_number, round_name'));

  // ── 6. Application round status ─────────────────────────────────────
  // Columns confirmed: application_id, round_id, attended, result
  // Valid result values (00015): pending, cleared, rejected, selected,
  //   not_selected, passed, failed
  final q6 = await _runQuery(
      'application_round_status',
      () => client
          .from('application_round_status')
          .select('application_id, round_id, attended, result'));

  // ── 7. Offers ───────────────────────────────────────────────────────
  // Columns confirmed: application_id, ctc_offered, status
  // (00016 renamed decision → status)
  final q7 = await _runQuery('offers',
      () => client.from('offers').select('application_id, ctc_offered, status'));

  // ── Collect per-query errors for UI display ─────────────────────────
  final Map<String, String> queryErrors = {};
  for (final q in [q1, q2, q3, q4, q5, q6, q7]) {
    if (q.failed) {
      final err = q.error;
      String msg;
      if (err is PostgrestException) {
        msg = 'PostgrestException [${err.code}]: ${err.message}'
            '${err.hint != null ? ' — hint: ${err.hint}' : ''}'
            '${err.details != null ? ' — details: ${err.details}' : ''}';
      } else {
        msg = err.toString();
      }
      queryErrors[q.queryName] = msg;
    }
  }

  if (kDebugMode && queryErrors.isNotEmpty) {
    dev.log('[Analytics] ${queryErrors.length} query/queries failed:\n'
        '${queryErrors.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}');
  }

  return _computeAnalytics(
    department: department,
    profilesList: q1.rows,
    drivesList: q2.rows,
    applicationsList: q3.rows,
    attendanceList: q4.rows,
    roundsList: q5.rows,
    roundStatusList: q6.rows,
    offersList: q7.rows,
    queryErrors: queryErrors,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Pure computation — operates only on the rows that succeeded
// ─────────────────────────────────────────────────────────────────────────────
DepartmentAnalyticsData _computeAnalytics({
  required String department,
  required List profilesList,
  required List drivesList,
  required List applicationsList,
  required List attendanceList,
  required List roundsList,
  required List roundStatusList,
  required List offersList,
  required Map<String, String> queryErrors,
}) {
  // ── Build lookup maps ──────────────────────────────────────────────
  final eligibleStudentIds = profilesList.map((p) => p['id'] as String).toSet();

  final appByStudentDrive = <String, Map<String, dynamic>>{};
  final appsByDrive = <String, List<Map<String, dynamic>>>{};
  final appsByStudent = <String, List<Map<String, dynamic>>>{};
  for (final a in applicationsList) {
    final aMap = a as Map<String, dynamic>;
    final sid = aMap['student_id'] as String;
    final did = aMap['drive_id'] as String;
    appByStudentDrive['$sid|$did'] = aMap;
    appsByDrive.putIfAbsent(did, () => []).add(aMap);
    appsByStudent.putIfAbsent(sid, () => []).add(aMap);
  }

  final attendanceByDrive = <String, Set<String>>{};
  for (final a in attendanceList) {
    final aMap = a as Map<String, dynamic>;
    final did = aMap['drive_id'] as String;
    final sid = aMap['student_id'] as String;
    attendanceByDrive.putIfAbsent(did, () => <String>{}).add(sid);
  }

  final roundsByDrive = <String, List<Map<String, dynamic>>>{};
  for (final r in roundsList) {
    final rMap = r as Map<String, dynamic>;
    final did = rMap['drive_id'] as String;
    roundsByDrive.putIfAbsent(did, () => []).add(rMap);
  }
  for (final entry in roundsByDrive.entries) {
    entry.value.sort(
        (a, b) => (a['round_number'] as int).compareTo(b['round_number'] as int));
  }

  final roundStatusByApp = <String, List<Map<String, dynamic>>>{};
  for (final rs in roundStatusList) {
    final rsMap = rs as Map<String, dynamic>;
    final aid = rsMap['application_id'] as String;
    roundStatusByApp.putIfAbsent(aid, () => []).add(rsMap);
  }

  final offersByApp = <String, Map<String, dynamic>>{};
  for (final o in offersList) {
    final oMap = o as Map<String, dynamic>;
    offersByApp[oMap['application_id'] as String] = oMap;
  }

  final driveMap = <String, Map<String, dynamic>>{};
  for (final d in drivesList) {
    final dMap = d as Map<String, dynamic>;
    driveMap[dMap['id'] as String] = dMap;
  }

  // ── Section 1 — Overview ───────────────────────────────────────────
  final appliedStudentIds = <String>{};
  for (final a in applicationsList) {
    final aMap = a as Map<String, dynamic>;
    if (eligibleStudentIds.contains(aMap['student_id'])) {
      appliedStudentIds.add(aMap['student_id'] as String);
    }
  }

  int offersCount = 0;
  final selectedStudentIds = <String>{};
  for (final a in applicationsList) {
    final aMap = a as Map<String, dynamic>;
    if (aMap['status'] == 'selected' &&
        eligibleStudentIds.contains(aMap['student_id'])) {
      selectedStudentIds.add(aMap['student_id'] as String);
      offersCount++;
    }
  }

  final eligible = eligibleStudentIds.length;
  final applied = appliedStudentIds.length;
  final placementPct =
      eligible > 0 ? (selectedStudentIds.length / eligible * 100) : 0.0;

  // ── Section 2 — Recruitment funnel ─────────────────────────────────
  final seenRoundNames = <String>[];
  for (final r in roundsList) {
    final rMap = r as Map<String, dynamic>;
    final name = rMap['round_name'] as String;
    if (!seenRoundNames.contains(name)) {
      seenRoundNames.add(name);
    }
  }

  final funnelCounts = <int>[];
  for (final roundName in seenRoundNames) {
    int count = 0;
    String? targetRoundId;
    for (final r in roundsList) {
      final rMap = r as Map<String, dynamic>;
      if (rMap['round_name'] == roundName) {
        targetRoundId = rMap['id'] as String;
        break;
      }
    }
    if (targetRoundId == null) {
      funnelCounts.add(0);
      continue;
    }
    for (final a in applicationsList) {
      final aMap = a as Map<String, dynamic>;
      final sid = aMap['student_id'] as String;
      final aid = aMap['id'] as String;
      if (!eligibleStudentIds.contains(sid)) continue;
      final statuses = roundStatusByApp[aid] ?? [];
      final hasPassed = statuses.any((s) =>
          s['round_id'] == targetRoundId && _isPassResult(s['result']));
      if (hasPassed) count++;
    }
    funnelCounts.add(count);
  }

  // ── Section 3 — Drive performance ──────────────────────────────────
  final driveAnalyticsList = <DriveAnalytics>[];
  for (final d in drivesList) {
    final dMap = d as Map<String, dynamic>;
    final driveId = dMap['id'] as String;

    // PostgREST returns the joined company data under the key 'companies'
    // (the alias used: companies!company_id → key is 'companies')
    final companyRaw = dMap['companies'];
    final company = companyRaw is Map
        ? companyRaw['name'] as String? ?? 'Unknown'
        : 'Unknown';

    final driveApps = appsByDrive[driveId] ?? [];
    final eligibleDriveApps = driveApps
        .where((a) => eligibleStudentIds.contains(a['student_id']))
        .toList();

    final appliedCount = eligibleDriveApps.length;
    final attendedCount = eligibleDriveApps
        .where((a) =>
            attendanceByDrive[driveId]?.contains(a['student_id']) ?? false)
        .length;
    final selectedCount =
        eligibleDriveApps.where((a) => a['status'] == 'selected').length;
    final rejectedCount =
        eligibleDriveApps.where((a) => a['status'] == 'rejected').length;
    final qualifiedCount =
        eligibleDriveApps.where((a) => a['status'] == 'shortlisted').length;

    final selectionPct =
        appliedCount > 0 ? (selectedCount / appliedCount * 100) : 0.0;

    final driveRounds = roundsByDrive[driveId] ?? [];
    final roundAnalyticsList = <RoundAnalytics>[];
    for (var ri = 0; ri < driveRounds.length; ri++) {
      final r = driveRounds[ri];
      final roundId = r['id'] as String;
      int entered;
      if (ri == 0) {
        entered = attendedCount;
      } else {
        final prevRoundId = driveRounds[ri - 1]['id'] as String;
        entered = eligibleDriveApps.where((a) {
          final statuses = roundStatusByApp[a['id'] as String] ?? [];
          return statuses.any((s) =>
              s['round_id'] == prevRoundId && _isPassResult(s['result']));
        }).length;
      }
      final qualified = eligibleDriveApps.where((a) {
        final statuses = roundStatusByApp[a['id'] as String] ?? [];
        return statuses.any((s) =>
            s['round_id'] == roundId && _isPassResult(s['result']));
      }).length;

      roundAnalyticsList.add(RoundAnalytics(
        roundName: r['round_name'] as String,
        entered: entered,
        qualified: qualified,
      ));
    }

    driveAnalyticsList.add(DriveAnalytics(
      driveId: driveId,
      companyName: company,
      role: (dMap['role'] ?? dMap['role_title'] ?? '') as String,
      status: (dMap['status'] ?? '') as String,
      deadline: dMap['end_date'] != null
          ? DateTime.tryParse(dMap['end_date'] as String)
          : null,
      applied: appliedCount,
      attendance: attendedCount,
      qualified: qualifiedCount,
      rejected: rejectedCount,
      selected: selectedCount,
      selectionPercent: selectionPct,
      rounds: roundAnalyticsList,
    ));
  }

  // ── Section 4 — Placement status donut ─────────────────────────────
  final selectedStudents = selectedStudentIds.length;
  final inProcess =
      appliedStudentIds.difference(selectedStudentIds).where((sid) {
    final studentApps = appsByStudent[sid] ?? [];
    return studentApps.any((a) =>
        a['status'] == 'applied' ||
        a['status'] == 'shortlisted' ||
        a['status'] == 'interview');
  }).length;
  final rejectedStudents =
      appliedStudentIds.difference(selectedStudentIds).where((sid) {
    final studentApps = appsByStudent[sid] ?? [];
    return studentApps.every((a) => a['status'] == 'rejected');
  }).length;
  final notApplied = eligible - applied;

  // ── Section 5 — Round performance ──────────────────────────────────
  final roundPerfQualified = <String, int>{};
  final roundPerfRejected = <String, int>{};
  for (final a in applicationsList) {
    final aMap = a as Map<String, dynamic>;
    final aid = aMap['id'] as String;
    final sid = aMap['student_id'] as String;
    if (!eligibleStudentIds.contains(sid)) continue;
    final statuses = roundStatusByApp[aid] ?? [];
    for (final s in statuses) {
      final roundId = s['round_id'] as String;
      String? rn;
      for (final r in roundsList) {
        final rMap = r as Map<String, dynamic>;
        if (rMap['id'] == roundId) {
          rn = rMap['round_name'] as String;
          break;
        }
      }
      if (rn == null) continue;
      if (_isPassResult(s['result'])) {
        roundPerfQualified[rn] = (roundPerfQualified[rn] ?? 0) + 1;
      } else if (s['result'] == 'rejected') {
        roundPerfRejected[rn] = (roundPerfRejected[rn] ?? 0) + 1;
      }
    }
  }

  final allRoundNames = <String>{
    ...roundPerfQualified.keys,
    ...roundPerfRejected.keys
  };
  final roundPerformanceList = allRoundNames.map((rn) {
    final q = roundPerfQualified[rn] ?? 0;
    final r = roundPerfRejected[rn] ?? 0;
    final total = q + r;
    return RoundPerformance(
      roundName: rn,
      qualified: q,
      rejected: r,
      passPercentage: total > 0 ? (q / total * 100) : 0,
    );
  }).toList();

  // ── Section 6 — Students needing attention ─────────────────────────
  int profileIncomplete = 0;
  int resumeMissing = 0;
  final List<String> resumeMissingStudentNames = [];
  int documentsPending = 0;
  for (final p in profilesList) {
    final pMap = p as Map<String, dynamic>;
    if (pMap['profile_completed'] != true) profileIncomplete++;
    if (pMap['resume_url'] == null ||
        (pMap['resume_url'] as String?)?.isEmpty == true) {
      resumeMissing++;
      final name = (pMap['name'] as String?) ?? 'Student';
      final usn = pMap['usn'] as String?;
      resumeMissingStudentNames.add(usn != null && usn.isNotEmpty ? '$name ($usn)' : name);
    }
    if (pMap['id_proof_url'] == null ||
        (pMap['id_proof_url'] as String?)?.isEmpty == true) {
      documentsPending++;
    }
  }

  int attendanceNotMarked = 0;
  for (final sid in appliedStudentIds) {
    final studentApps = appsByStudent[sid] ?? [];
    final hasAttended = studentApps.any((a) =>
        attendanceByDrive[a['drive_id'] as String]?.contains(sid) ?? false);
    if (!hasAttended) attendanceNotMarked++;
  }

  final eligibleNotApplied = eligible - applied;

  // ── Section 7 — Quick insights ─────────────────────────────────────
  String highestAppliedDrive = '—';
  int maxApplied = 0;
  String highestPackageDrive = '—';
  double maxPackage = 0;
  String lowestParticipationDrive = '—';
  int minApplied = 999999;

  double totalCgpa = 0;
  int cgpaCount = 0;
  for (final p in profilesList) {
    final pMap = p as Map<String, dynamic>;
    final cgpa = (pMap['cgpa'] as num?)?.toDouble();
    if (cgpa != null && cgpa > 0) {
      totalCgpa += cgpa;
      cgpaCount++;
    }
  }

  for (final da in driveAnalyticsList) {
    if (da.applied > maxApplied) {
      maxApplied = da.applied;
      highestAppliedDrive = '${da.companyName} — ${da.role}';
    }
    if (da.applied > 0 && da.applied < minApplied) {
      minApplied = da.applied;
      lowestParticipationDrive = '${da.companyName} — ${da.role}';
    }
    final d = driveMap[da.driveId];
    if (d != null) {
      final pkg = d['package_lpa'];
      if (pkg != null) {
        final pkgStr = pkg.toString();
        final numVal =
            double.tryParse(pkgStr.replaceAll(RegExp(r'[^0-9.]'), ''));
        if (numVal != null && numVal > maxPackage) {
          maxPackage = numVal;
          highestPackageDrive = '${da.companyName} — ${da.role}';
        }
      }
    }
  }

  if (minApplied == 999999) lowestParticipationDrive = '—';

  final totalAttendanceAcrossDrives =
      attendanceByDrive.values.fold<int>(0, (sum, s) => sum + s.length);
  final totalAppliedAcrossDrives = applicationsList.length;
  final attendancePct = totalAppliedAcrossDrives > 0
      ? (totalAttendanceAcrossDrives / totalAppliedAcrossDrives * 100)
      : 0.0;

  final appRate = eligible > 0 ? (applied / eligible * 100) : 0.0;
  final convRate = applied > 0 ? (selectedStudents / applied * 100) : 0.0;

  return DepartmentAnalyticsData(
    department: department,
    eligibleStudents: eligible,
    appliedStudents: applied,
    offersReceived: offersCount,
    placementPercentage: placementPct,
    roundNames: seenRoundNames,
    funnelCounts: funnelCounts,
    drives: driveAnalyticsList,
    selectedCount: selectedStudents,
    inProcessCount: inProcess,
    rejectedCount: rejectedStudents,
    notAppliedCount: notApplied < 0 ? 0 : notApplied,
    roundPerformance: roundPerformanceList,
    profileIncomplete: profileIncomplete,
    resumeMissing: resumeMissing,
    resumeMissingStudentNames: resumeMissingStudentNames,
    attendanceNotMarked: attendanceNotMarked,
    eligibleButNotApplied: eligibleNotApplied < 0 ? 0 : eligibleNotApplied,
    documentsPending: documentsPending,
    highestAppliedDrive: highestAppliedDrive,
    highestPackageDrive: highestPackageDrive,
    lowestParticipationDrive: lowestParticipationDrive,
    avgCgpa: cgpaCount > 0 ? totalCgpa / cgpaCount : 0,
    departmentApplicationRate: appRate,
    offerConversionRate: convRate,
    attendancePercentage: attendancePct,
    queryErrors: queryErrors,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: any value that means "passed this round"
// Valid result values (migration 00015):
//   pending | cleared | rejected | selected | not_selected | passed | failed
// ─────────────────────────────────────────────────────────────────────────────
bool _isPassResult(dynamic result) {
  return result == 'cleared' || result == 'passed' || result == 'selected';
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────
final departmentAnalyticsProvider =
    FutureProvider.family<DepartmentAnalyticsData, String>((ref, department) {
  return fetchDepartmentAnalytics(department);
});
