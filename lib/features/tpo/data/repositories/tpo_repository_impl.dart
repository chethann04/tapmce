import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../shared/domain/entities/company.dart';
import '../../../student/domain/entities/drive.dart';
import '../../../student/domain/entities/application.dart';
import '../../domain/repositories/tpo_repository.dart';
import '../../domain/entities/drive_round.dart';

import '../../../audit/domain/entities/audit_log_entry.dart';
import '../../../audit/domain/repositories/audit_log_repository.dart';

import '../../../../core/services/email_notification_service.dart';

class TpoRepositoryImpl implements TpoRepository {
  final SupabaseClient _supabase;
  final AuditLogRepository _auditLogRepo;
  final EmailNotificationService? _emailService;

  TpoRepositoryImpl(this._supabase, this._auditLogRepo, [this._emailService]);

  @override
  Future<void> appointFacultyCoordinator({
    required String profileId,
    required String department,
    required String appointedBy,
  }) async {
    // Check existing coordinator to prevent duplicate department appointment
    final existing = await _supabase
        .from('faculty_coordinators')
        .select('id')
        .eq('department', department)
        .maybeSingle();

    if (existing != null) {
      await _supabase.from('faculty_coordinators').update({
        'profile_id': profileId,
        'appointed_by': appointedBy,
      }).eq('department', department);
    } else {
      await _supabase.from('faculty_coordinators').insert({
        'profile_id': profileId,
        'department': department,
        'appointed_by': appointedBy,
      });
    }

    // Update department and attempt role update on profile safely
    try {
      await _supabase.from('profiles').update({
        'role': 'faculty_coordinator',
        'department': department,
      }).eq('id', profileId);
    } catch (_) {
      // If profile role update is restricted by Postgres trigger (P0001), update department only
      await _supabase.from('profiles').update({
        'department': department,
      }).eq('id', profileId);
    }

    // Roles are exclusive: remove any previous TPO appointment so this user
    // is not shown as TPO while being a department coordinator
    await _supabase
        .from('tpo_appointments')
        .delete()
        .eq('profile_id', profileId);

    // Dispatch email notification asynchronously
    try {
      final profile = await _supabase
          .from('profiles')
          .select('name, email')
          .eq('id', profileId)
          .maybeSingle();

      if (profile != null && profile['email'] != null && _emailService != null) {
        _emailService!.sendFacultyAppointmentEmail(
          recipientEmail: profile['email'] as String,
          facultyName: (profile['name'] as String?) ?? 'Faculty Member',
          department: department,
        );
      }

      // Push notification to the newly appointed faculty coordinator
      if (profile != null) {
        try {
          await _supabase.functions.invoke('send-fcm-push', body: {
            'user_ids': [profileId],
            'title': 'Faculty Appointment',
            'body': 'You have been appointed as Faculty Coordinator for $department.',
          });
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFacultyCoordinators() async {
    final response = await _supabase
        .from('faculty_coordinators')
        .select('*, profile:profiles!faculty_coordinators_profile_id_fkey(name, email, phone)');
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<void> createCompany({
    required String name,
    String? industry,
    String? hrContactName,
    String? hrContactEmail,
    String? hrContactPhone,
    required String createdBy,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    // Check if company already exists to avoid duplicate inserts
    final existing = await _supabase
        .from('companies')
        .select('id')
        .ilike('name', cleanName)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from('companies').insert({
        'name': cleanName,
        if (industry != null) 'industry': industry,
        if (hrContactName != null) 'hr_contact_name': hrContactName,
        if (hrContactEmail != null) 'hr_contact_email': hrContactEmail,
        if (hrContactPhone != null) 'hr_contact_phone': hrContactPhone,
      });
    }
  }

  @override
  Future<void> updateCompany({
    required String companyId,
    required String name,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || companyId.isEmpty) return;
    await _supabase
        .from('companies')
        .update({'name': cleanName})
        .eq('id', companyId);
  }

  @override
  Future<List<Company>> getCompanies() async {
    final response = await _supabase.from('companies').select('*');
    return (response as List).map((map) => Company.fromMap(map)).toList();
  }

  final List<Drive> _localDriveCache = [];

  @override
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
  }) async {
    // Parse numerical package if provided (e.g. "20LPA" or "12" -> 20.0 or 12.0)
    double? packageLpa;
    if (ctcOrStipend != null && ctcOrStipend.isNotEmpty) {
      final numericStr = ctcOrStipend.replaceAll(RegExp(r'[^0-9.]'), '');
      packageLpa = double.tryParse(numericStr);
    }

    final payload = <String, dynamic>{
      'company_id': companyId.isNotEmpty ? companyId : null,
      'role': roleTitle,
      'role_title': roleTitle,
      'description': jobDescription,
      if (packageLpa != null) 'package_lpa': packageLpa,
      'eligibility_cgpa': cgpaCutoff ?? 0.0,
      'eligibility_branches': eligibilityBranches ?? [],
      'backlog_limit': backlogLimit ?? 0,
      if (applicationDeadline != null) 'end_date': applicationDeadline.toIso8601String(),
      'status': status == 'active' ? 'upcoming' : status,
    };

    // ignore: avoid_print
    print('🚀 [TpoRepository] Submitting drive insert payload to Supabase: $payload');

    try {
      final response = await _supabase
          .from('drives')
          .insert(payload)
          .select('*, company:companies(*)')
          .maybeSingle();

      if (response != null) {
        final drive = Drive.fromMap(response);
        _localDriveCache.removeWhere((d) => d.id == drive.id);
        _localDriveCache.insert(0, drive);

        try {
          await _auditLogRepo.logAction(
            action: AuditAction.driveCreated,
            description: 'Created new placement drive: $roleTitle',
            targetId: drive.id,
            targetTable: 'drives',
          );
        } catch (_) {}

        return drive.id;
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('❌ [TpoRepository] Supabase insert error: $e\n$stack');
      rethrow;
    }
    return '';
  }

  @override
  Future<void> updateDriveStatus({
    required String driveId,
    required String status,
  }) async {
    final validStatus = status.toLowerCase() == 'ongoing'
        ? 'active'
        : (status.toLowerCase() == 'closed' ? 'completed' : status.toLowerCase());

    // 1. Update in local memory cache immediately
    final index = _localDriveCache.indexWhere((d) => d.id == driveId);
    if (index != -1) {
      final old = _localDriveCache[index];
      _localDriveCache[index] = Drive(
        id: old.id,
        companyId: old.companyId,
        companyName: old.companyName,
        roleTitle: old.roleTitle,
        ctcOrStipend: old.ctcOrStipend,
        jobDescription: old.jobDescription,
        eligibilityBranches: old.eligibilityBranches,
        cgpaCutoff: old.cgpaCutoff,
        backlogLimit: old.backlogLimit,
        applicationDeadline: old.applicationDeadline,
        status: validStatus,
      );
    }

    // 2. Persist to Supabase database
    try {
      // ignore: avoid_print
      print('🚀 [TpoRepository] Updating Supabase drive $driveId status -> $validStatus');
      
      await _supabase
          .from('drives')
          .update({'status': validStatus})
          .eq('id', driveId);
          
      // ignore: avoid_print
      print('✅ [TpoRepository] Supabase update successful for status: $validStatus');

      // Dispatch event-driven email notifications
      if (_emailService != null) {
        try {
          final driveRes = await _supabase
              .from('drives')
              .select('role_title, ctc_or_stipend, application_deadline, start_date, company:companies!company_id(name)')
              .eq('id', driveId)
              .maybeSingle();

          if (driveRes != null) {
            final companyName = (driveRes['company'] is Map ? (driveRes['company'] as Map)['name'] : null) ?? 'Company';
            final roleTitle = (driveRes['role_title'] as String?) ?? 'Job Role';

            if (validStatus == 'active' || validStatus == 'open') {
              // Notify all eligible approved students
              final students = await _supabase
                  .from('profiles')
                  .select('id, email, name')
                  .eq('role', 'student')
                  .eq('approval_status', 'approved');

              final studentIds = <String>[];
              for (final s in (students as List)) {
                final email = s['email'] as String?;
                final name = (s['name'] as String?) ?? 'Student';
                final sid = s['id'] as String?;
                if (sid != null && sid.isNotEmpty) studentIds.add(sid);
                if (email != null && email.isNotEmpty) {
                  _emailService!.sendDrivePublishedEmail(
                    recipientEmail: email,
                    studentName: name,
                    companyName: companyName,
                    roleTitle: roleTitle,
                    package: (driveRes['ctc_or_stipend'] as String?) ?? 'As per policy',
                    registrationDeadline: (driveRes['application_deadline'] as String?) ?? 'N/A',
                  );
                }
              }

              if (studentIds.isNotEmpty) {
                try {
                  await _supabase.functions.invoke('send-fcm-push', body: {
                    'user_ids': studentIds,
                    'drive_id': driveId,
                    'title': 'Drive Activated',
                    'body': '$companyName - $roleTitle applications are now open. Apply before the deadline!',
                  });
                } catch (_) {}
              }
            } else if (validStatus == 'cancelled') {
              // Notify applicants
              final apps = await _supabase
                  .from('applications')
                  .select('student_id, profile:profiles!applications_student_id_fkey(email)')
                  .eq('drive_id', driveId);

              final studentIds = <String>[];
              for (final a in (apps as List)) {
                final profile = a['profile'];
                final email = profile is Map ? profile['email'] as String? : null;
                final sid = a['student_id'] as String?;
                if (sid != null && sid.isNotEmpty) studentIds.add(sid);
                if (email != null && email.isNotEmpty) {
                  _emailService!.sendDriveCancelledEmail(
                    recipientEmail: email,
                    companyName: companyName,
                    reason: 'Drive status updated to cancelled by TPO.',
                  );
                }
              }

              if (studentIds.isNotEmpty) {
                try {
                  await _supabase.functions.invoke('send-fcm-push', body: {
                    'user_ids': studentIds,
                    'drive_id': driveId,
                    'title': 'Drive Cancelled',
                    'body': 'The drive for $companyName - $roleTitle has been cancelled by TPO.',
                  });
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ [TpoRepository] First update attempt failed: $e. Retrying with fallback status...');
      try {
        // Fallback for custom DB enums where 'active' is named 'ongoing'
        final fallbackStatus = validStatus == 'active' ? 'ongoing' : (validStatus == 'completed' ? 'closed' : validStatus);
        await _supabase
            .from('drives')
            .update({'status': fallbackStatus})
            .eq('id', driveId);
            
      } catch (err) {
        // ignore: avoid_print
        print('❌ [TpoRepository] Supabase drive status update completely failed: $err');
      }
    }
  }

  @override
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
  }) async {
    double? packageLpa;
    if (ctcOrStipend != null && ctcOrStipend.isNotEmpty) {
      final numericStr = ctcOrStipend.replaceAll(RegExp(r'[^0-9.]'), '');
      packageLpa = double.tryParse(numericStr);
    }

    final payload = <String, dynamic>{
      if (companyId != null && companyId.isNotEmpty) 'company_id': companyId,
      'role': roleTitle,
      'role_title': roleTitle,
      if (jobDescription != null) 'description': jobDescription,
      if (packageLpa != null) 'package_lpa': packageLpa,
      if (cgpaCutoff != null) 'eligibility_cgpa': cgpaCutoff,
      if (eligibilityBranches != null) 'eligibility_branches': eligibilityBranches,
      if (backlogLimit != null) 'backlog_limit': backlogLimit,
      if (applicationDeadline != null) 'end_date': applicationDeadline.toIso8601String(),
    };

    // ignore: avoid_print
    print('🚀 [TpoRepository] Updating drive $driveId in Supabase: $payload');

    final response = await _supabase
        .from('drives')
        .update(payload)
        .eq('id', driveId)
        .select('*, company:companies(*)')
        .maybeSingle();

    if (response != null) {
      final updatedDrive = Drive.fromMap(response);
      final idx = _localDriveCache.indexWhere((d) => d.id == driveId);
      if (idx != -1) {
        _localDriveCache[idx] = updatedDrive;
      }

      // Notify registered applicants about updated drive details/schedule
      try {
        final apps = await _supabase
            .from('applications')
            .select('student_id')
            .eq('drive_id', driveId);
        final studentIds = (apps as List)
            .map((a) => a['student_id'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toList();

        if (studentIds.isNotEmpty) {
          final compName = updatedDrive.companyName.isNotEmpty ? updatedDrive.companyName : 'Company';
          for (final sid in studentIds) {
            await _supabase.from('notifications').insert({
              'user_id': sid,
              'title': '🚨 Drive Updated: $compName',
              'body': 'The recruitment details or schedule for $roleTitle have been updated by TPO.',
              'type': 'drive_updated',
              'drive_id': driveId,
            });
          }
          await _supabase.functions.invoke('send-fcm-push', body: {
            'user_ids': studentIds,
            'title': '🚨 Drive Updated: $compName',
            'body': 'The recruitment details or schedule for $roleTitle have been updated by TPO.',
            'drive_id': driveId,
          });
        }
      } catch (_) {}
    }
  }

  @override
  Future<List<Drive>> getDrives() async {
    try {
      final response = await _supabase
          .from('drives')
          .select('*, company:companies(*), drive_rounds(*)')
          .order('created_at', ascending: false);
      return (response as List).map((map) => Drive.fromMap(map)).toList();
    } catch (e) {
      try {
        // Fallback: fetch drives without nested drive_rounds if join schema fails
        final fallback = await _supabase
            .from('drives')
            .select('*, company:companies(*)')
            .order('created_at', ascending: false);
        return (fallback as List).map((map) => Drive.fromMap(map)).toList();
      } catch (err) {
        return _localDriveCache;
      }
    }
  }

  @override
  Future<void> updateApplicationStatus({
    required String applicationId,
    required ApplicationStatus status,
  }) async {
    await _supabase
        .from('applications')
        .update({'status': status.name}).eq('id', applicationId);
  }

  @override
  Future<void> bulkUpdateShortlist({
    required String driveId,
    required List<String> studentIds,
    required ApplicationStatus status,
  }) async {
    for (final studentId in studentIds) {
      await _supabase
          .from('applications')
          .update({'status': status.name})
          .eq('drive_id', driveId)
          .eq('student_id', studentId);
    }
  }

  @override
  Future<void> uploadOffer({
    required String applicationId,
    required double ctc,
    required String offerLetterUrl,
    required DateTime joiningDate,
  }) async {
    await _supabase.from('offers').insert({
      'application_id': applicationId,
      'ctc_offered': ctc,
      'offer_letter_url': offerLetterUrl,
      'joining_date': joiningDate.toIso8601String(),
      'status': 'offered',
    });
    await _supabase
        .from('applications')
        .update({'status': 'selected'}).eq('id', applicationId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDriveAttendance(String driveId) async {
    final response = await _supabase
        .from('drive_attendance')
        .select('*, profile:profiles!drive_attendance_student_id_fkey(name, email, usn, department)')
        .eq('drive_id', driveId)
        .order('scanned_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // ── Round Management ──────────────────────────────────────────────────

  @override
  Future<void> saveDriveRounds({
    required String driveId,
    required List<String> roundNames,
    required String createdBy,
  }) async {
    // Delete existing rounds for this drive
    await _supabase.from('drive_rounds').delete().eq('drive_id', driveId);

    // Insert new rounds
    if (roundNames.isEmpty) return;

    final rounds = <Map<String, dynamic>>[];
    for (var i = 0; i < roundNames.length; i++) {
      rounds.add({
        'drive_id': driveId,
        'round_number': i + 1,
        'round_name': roundNames[i],
        'created_by': createdBy,
      });
    }

    await _supabase.from('drive_rounds').insert(rounds);

    // Update rounds_count on the drive
    await _supabase
        .from('drives')
        .update({'rounds_count': roundNames.length})
        .eq('id', driveId);
  }

  @override
  Future<List<DriveRound>> getDriveRounds(String driveId) async {
    final response = await _supabase
        .from('drive_rounds')
        .select()
        .eq('drive_id', driveId)
        .order('round_number', ascending: true);

    return (response as List)
        .map((map) => DriveRound.fromMap(map))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getRoundStudents({
    required String driveId,
    required int roundNumber,
  }) async {
    // Step 1: Get the round_id for this stage
    final roundRow = await _supabase
        .from('drive_rounds')
        .select('id')
        .eq('drive_id', driveId)
        .eq('round_number', roundNumber)
        .maybeSingle();

    // Fallback for round 1 if no drive_rounds row yet: use attendance-based approach
    if (roundRow == null && roundNumber == 1) {
      final attendanceResponse = await _supabase
          .from('drive_attendance')
          .select('student_id, scanned_at, status')
          .eq('drive_id', driveId);

      if ((attendanceResponse as List).isEmpty) return [];

      final attendedStudentIds = <String>{};
      final attendedAtMap = <String, dynamic>{};
      final attendanceStatusMap = <String, dynamic>{};
      for (final a in attendanceResponse) {
        final sid = a['student_id'] as String;
        attendedStudentIds.add(sid);
        attendedAtMap[sid] = a['scanned_at'];
        attendanceStatusMap[sid] = a['status'];
      }

      final appsResponse = await _supabase
          .from('applications')
          .select(
              'id, status, applied_at, student_id, current_round, '
              'student:profiles!applications_student_id_fkey(name, email, usn, department, cgpa, semester, photo_url)')
          .eq('drive_id', driveId)
          .order('applied_at', ascending: false);

      final results = <Map<String, dynamic>>[];
      for (final app in appsResponse as List) {
        final sid = app['student_id'] as String;
        if (!attendedStudentIds.contains(sid)) continue;
        results.add({
          ...app as Map<String, dynamic>,
          'attended_at': attendedAtMap[sid],
          'attendance_status': attendanceStatusMap[sid],
          'round_result': 'pending', // will be enriched below if possible
        });
      }
      return results;
    }

    if (roundRow == null) return [];
    final roundId = roundRow['id'] as String;

    // Step 2: Fetch ALL application_round_status records for this round
    // This gives us every student who was ever in this stage — including those who cleared and moved on.
    final statusRows = await _supabase
        .from('application_round_status')
        .select('application_id, result, attended, updated_at')
        .eq('round_id', roundId);

        if ((statusRows as List).isEmpty) {
      final appsResponse = await _supabase
          .from('applications')
          .select('id, status, applied_at, student_id, current_round, student:profiles!applications_student_id_fkey(name, email, usn, department, cgpa, semester, photo_url)')
          .eq('drive_id', driveId)
          .order('applied_at', ascending: false);

      List<dynamic> attendanceResponse = [];
      try {
        attendanceResponse = await _supabase
            .from('drive_attendance')
            .select('student_id, scanned_at, status')
            .eq('drive_id', driveId);
      } catch (_) {}

      final attendedMap = <String, Map<String, dynamic>>{};
      for (final a in attendanceResponse) {
        if (a is Map<String, dynamic>) {
          attendedMap[a['student_id'] as String] = a;
        }
      }

      final results = <Map<String, dynamic>>[];
      for (final app in (appsResponse as List)) {
        final sid = app['student_id'] as String;
        final appRound = app['current_round'] as int? ?? 1;
        if (roundNumber > 1 && appRound < roundNumber) continue;

        final att = attendedMap[sid];
        results.add({
          ...app as Map<String, dynamic>,
          'round_result': 'pending',
          'attended': att != null,
          'attended_at': att?['scanned_at'],
          'attendance_status': att?['status'] ?? (att != null ? 'present' : null),
        });
      }
      return results;
    }

    // Step 3: Collect application IDs
    final appIds = (statusRows as List).map((r) => r['application_id'] as String).toList();
    final resultMap = <String, Map<String, dynamic>>{};
    for (final r in statusRows) {
      resultMap[r['application_id'] as String] = {
        'round_result': r['result'] as String? ?? 'pending',
        'attended': r['attended'] as bool? ?? false,
        'round_updated_at': r['updated_at'],
      };
    }

    // Step 4: Fetch full application + student info for those IDs
    final appsResponse = await _supabase
        .from('applications')
        .select(
            'id, status, applied_at, student_id, current_round, '
            'student:profiles!applications_student_id_fkey(name, email, usn, department, cgpa, semester, photo_url)')
        .inFilter('id', appIds)
        .order('applied_at', ascending: false);

    // Step 5: Merge — attach the per-stage result to each application row
    final results = <Map<String, dynamic>>[];
    for (final app in appsResponse as List) {
      final appId = app['id'] as String;
      final stageInfo = resultMap[appId] ?? {};
      results.add({
        ...app as Map<String, dynamic>,
        'round_result': stageInfo['round_result'] ?? 'pending',
        'attended': stageInfo['attended'] ?? false,
        'attended_at': stageInfo['round_updated_at'],
        'attendance_status': (stageInfo['attended'] == true) ? 'present' : null,
      });
    }
    return results;
  }

  @override
  Future<void> moveStudentsToNextRound({
    required String driveId,
    required int currentRoundNumber,
    required List<String> applicationIds,
    required String performedBy,
  }) async {
    final nextRound = currentRoundNumber + 1;

    for (final appId in applicationIds) {
      // Get application details to check current round
      final appData = await _supabase
          .from('applications')
          .select('student_id, current_round')
          .eq('id', appId)
          .maybeSingle();

      if (appData == null) continue;
      final studentId = appData['student_id'] as String? ?? '';
      final appCurrentRound = appData['current_round'] as int? ?? 1;

      // PREVENT DUPLICATE PROMOTION:
      // If student is already past currentRoundNumber, do not promote again.
      if (appCurrentRound != currentRoundNumber) {
        continue;
      }

      // AUTOMATIC PREREQUISITE STAGE COMPLETION:
      // Mark current and all previous rounds (<= currentRoundNumber) as completed/cleared
      final prevRounds = await _supabase
          .from('drive_rounds')
          .select('id, round_number')
          .eq('drive_id', driveId)
          .lte('round_number', currentRoundNumber);

      for (final r in prevRounds) {
        await _supabase.from('application_round_status').upsert({
          'application_id': appId,
          'round_id': r['id'],
          'attended': true,
          'result': 'cleared',
          
        }, onConflict: 'application_id,round_id');
      }

      // Update current_round and status on the application
      await _supabase
          .from('applications')
          .update({
            'current_round': nextRound,
            'status': 'shortlisted',
            
          })
          .eq('id', appId);

      // Get the round_id for the next round
      final nextRoundData = await _supabase
          .from('drive_rounds')
          .select('id')
          .eq('drive_id', driveId)
          .eq('round_number', nextRound)
          .maybeSingle();

      if (nextRoundData != null) {
        // Create application_round_status for the next round
        await _supabase.from('application_round_status').upsert({
          'application_id': appId,
          'round_id': nextRoundData['id'],
          'result': 'pending',
          
        }, onConflict: 'application_id,round_id');
      }

      // Log audit
      try {
        await _auditLogRepo.logAction(
          action: AuditAction.other,
          description: 'Student moved from round $currentRoundNumber to round $nextRound',
          targetId: appId,
          targetTable: 'applications',
        );
      } catch (_) {}

      // Send notification to student
      await sendNotification(
        userId: studentId,
        title: 'Round Progress Update',
        body: 'Congratulations! You have been promoted to Round $nextRound. Please check the round details.',
        type: 'success',
        driveId: driveId,
        applicationId: appId,
      );

      // Email dispatch for round promotion
      if (_emailService != null) {
        try {
          final studentProfile = await _supabase
              .from('profiles')
              .select('name, email')
              .eq('id', studentId)
              .maybeSingle();

          final driveInfo = await _supabase
              .from('drives')
              .select('role_title, company:companies!company_id(name)')
              .eq('id', driveId)
              .maybeSingle();

          // Fetch real round names from drive_rounds
          final currentRoundInfo = await _supabase
              .from('drive_rounds')
              .select('round_name')
              .eq('drive_id', driveId)
              .eq('round_number', currentRoundNumber)
              .maybeSingle();
          final nextRoundInfo = await _supabase
              .from('drive_rounds')
              .select('round_name')
              .eq('drive_id', driveId)
              .eq('round_number', nextRound)
              .maybeSingle();

          final currentRoundName = (currentRoundInfo?['round_name'] as String?) ?? 'Round $currentRoundNumber';
          final nextRoundName = (nextRoundInfo?['round_name'] as String?) ?? 'Round $nextRound';

          if (studentProfile != null && studentProfile['email'] != null && driveInfo != null) {
            final compName = (driveInfo['company'] is Map ? (driveInfo['company'] as Map)['name'] : null) ?? 'Company';
            _emailService!.sendRoundQualifiedEmail(
              recipientEmail: studentProfile['email'] as String,
              studentName: (studentProfile['name'] as String?) ?? 'Student',
              companyName: compName,
              qualifiedRound: currentRoundName,
              nextRoundName: nextRoundName,
            );
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> offerStudents({
    required String driveId,
    required int currentRoundNumber,
    required List<String> applicationIds,
    required String performedBy,
  }) async {
    for (final appId in applicationIds) {
      // Get student_id for notification
      final appData = await _supabase
          .from('applications')
          .select('student_id')
          .eq('id', appId)
          .maybeSingle();
      final studentId = appData?['student_id'] as String? ?? '';

      // Update application status to selected
      await _supabase
          .from('applications')
          .update({'status': 'selected'})
          .eq('id', appId);

      // Mark all rounds up to currentRoundNumber as cleared/attended in application_round_status
      final allRounds = await _supabase
          .from('drive_rounds')
          .select('id, round_number')
          .eq('drive_id', driveId)
          .lte('round_number', currentRoundNumber);

      for (final r in (allRounds as List)) {
        await _supabase.from('application_round_status').upsert({
          'application_id': appId,
          'round_id': r['id'],
          'attended': true,
          'result': 'cleared',
        }, onConflict: 'application_id,round_id');
      }

      // Log audit
      try {
        await _auditLogRepo.logAction(
          action: AuditAction.other,
          description: 'Student offered selection for drive',
          targetId: appId,
          targetTable: 'applications',
        );
      } catch (_) {}

      // Send in-app notification to student
      if (studentId.isNotEmpty) {
        await sendNotification(
          userId: studentId,
          title: '🎉 Placement Offer Released!',
          body: 'Congratulations! You have received an offer from recruitment selection.',
          type: 'offer',
          driveId: driveId,
          applicationId: appId,
        );
      }

      // Email dispatch for offer selection & Faculty coordinator push notification
      if (studentId.isNotEmpty) {
        try {
          final studentProfile = await _supabase
              .from('profiles')
              .select('name, email, department, usn')
              .eq('id', studentId)
              .maybeSingle();

          final driveInfo = await _supabase
              .from('drives')
              .select('role_title, ctc_or_stipend, company:companies!company_id(name)')
              .eq('id', driveId)
              .maybeSingle();

          if (studentProfile != null && driveInfo != null) {
            final compName = (driveInfo['company'] is Map ? (driveInfo['company'] as Map)['name'] : null) ?? 'Company';
            final studentName = (studentProfile['name'] as String?) ?? 'Student';
            final roleTitle = (driveInfo['role_title'] as String?) ?? '';
            final package = (driveInfo['ctc_or_stipend'] as String?) ?? '';
            final dept = studentProfile['department'] as String?;

            if (_emailService != null && studentProfile['email'] != null) {
              _emailService!.sendOfferReleasedEmail(
                recipientEmail: studentProfile['email'] as String,
                studentName: studentName,
                companyName: compName,
                roleTitle: roleTitle,
                package: package,
              );
            }

            // Also alert the Faculty Coordinator of that department
            if (dept != null && dept.isNotEmpty) {
              try {
                final coordinators = await _supabase
                    .from('profiles')
                    .select('id')
                    .eq('department', dept)
                    .filter('role', 'in', ['faculty', 'coordinator']);
                final coordIds = (coordinators as List).map((c) => c['id'] as String).toList();
                if (coordIds.isNotEmpty) {
                  for (final cId in coordIds) {
                    await _supabase.from('notifications').insert({
                      'user_id': cId,
                      'title': '🎉 Student Placed: $dept',
                      'body': '$studentName has received a job offer from $compName ($package)!',
                      'type': 'placed_alert',
                      'drive_id': driveId,
                    });
                  }
                  await _supabase.functions.invoke('send-fcm-push', body: {
                    'user_ids': coordIds,
                    'title': '🎉 Student Placed: $dept',
                    'body': '$studentName has received a job offer from $compName ($package)!',
                    'drive_id': driveId,
                  });
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> rejectStudents({
    required String driveId,
    required int currentRoundNumber,
    required List<String> applicationIds,
    String? remarks,
    required String performedBy,
  }) async {
    for (final appId in applicationIds) {
      // Get student_id for notification
      final appData = await _supabase
          .from('applications')
          .select('student_id')
          .eq('id', appId)
          .maybeSingle();
      final studentId = appData?['student_id'] as String? ?? '';

      // Update application status to rejected
      await _supabase
          .from('applications')
          .update({'status': 'rejected'})
          .eq('id', appId);

      // Get the current round_id
      final roundData = await _supabase
          .from('drive_rounds')
          .select('id')
          .eq('drive_id', driveId)
          .eq('round_number', currentRoundNumber)
          .maybeSingle();

      if (roundData != null) {
        // Update application_round_status with rejection (attended: true since they were present)
        await _supabase.from('application_round_status').upsert({
          'application_id': appId,
          'round_id': roundData['id'],
          'attended': true,
          'result': 'rejected',
        }, onConflict: 'application_id,round_id');
      }

      // Log audit
      try {
        await _auditLogRepo.logAction(
          action: AuditAction.other,
          description: 'Student rejected at round $currentRoundNumber${remarks != null ? ': $remarks' : ''}',
          targetId: appId,
          targetTable: 'applications',
        );
      } catch (_) {}

      // Send notification
      await sendNotification(
        userId: studentId,
        title: 'Application Update',
        body: 'Your application has not progressed to the next round.${remarks != null ? ' Remarks: $remarks' : ''}',
        type: 'warning',
        driveId: driveId,
        applicationId: appId,
      );

      // Email dispatch for round rejection
      if (_emailService != null) {
        try {
          final studentProfile = await _supabase
              .from('profiles')
              .select('name, email')
              .eq('id', studentId)
              .maybeSingle();

          final driveInfo = await _supabase
              .from('drives')
              .select('role_title, company:companies!company_id(name)')
              .eq('id', driveId)
              .maybeSingle();

          if (studentProfile != null && studentProfile['email'] != null && driveInfo != null) {
            final compName = (driveInfo['company'] is Map ? (driveInfo['company'] as Map)['name'] : null) ?? 'Company';
            _emailService!.sendRoundRejectedEmail(
              recipientEmail: studentProfile['email'] as String,
              studentName: (studentProfile['name'] as String?) ?? 'Student',
              companyName: compName,
              rejectedRound: 'Round $currentRoundNumber',
              remarks: remarks,
            );
          }
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> markStudentsAbsent({
    required String driveId,
    required int currentRoundNumber,
    required List<String> applicationIds,
    required String performedBy,
  }) async {
    for (final appId in applicationIds) {
      // Get student_id for notification and attendance update
      final appData = await _supabase
          .from('applications')
          .select('student_id')
          .eq('id', appId)
          .maybeSingle();
      final studentId = appData?['student_id'] as String? ?? '';

      // Mark attendance as absent in drive_attendance
      if (studentId.isNotEmpty) {
        await _supabase
            .from('drive_attendance')
            .update({'status': 'absent'})
            .eq('drive_id', driveId)
            .eq('student_id', studentId);
      }

      // Get the current round_id
      final roundData = await _supabase
          .from('drive_rounds')
          .select('id')
          .eq('drive_id', driveId)
          .eq('round_number', currentRoundNumber)
          .maybeSingle();

      if (roundData != null) {
        // Update application_round_status with absent
        await _supabase.from('application_round_status').upsert({
          'application_id': appId,
          'round_id': roundData['id'],
          'attended': false,
          'result': 'rejected',
        }, onConflict: 'application_id,round_id');
      }

      // Update application status
      await _supabase
          .from('applications')
          .update({'status': 'rejected'})
          .eq('id', appId);

      // Log audit
      try {
        await _auditLogRepo.logAction(
          action: AuditAction.other,
          description: 'Student marked absent at round $currentRoundNumber',
          targetId: appId,
          targetTable: 'applications',
        );
      } catch (_) {}

      // Send notification
      await sendNotification(
        userId: studentId,
        title: 'Attendance Update',
        body: 'You have been marked absent for Round $currentRoundNumber. Your application has been closed.',
        type: 'warning',
        driveId: driveId,
        applicationId: appId,
      );
    }
  }

  @override
  Future<void> addRoundRemarks({
    required String applicationId,
    required String roundId,
    required String remarks,
    required String performedBy,
  }) async {
    try {
      await _auditLogRepo.logAction(
        action: AuditAction.other,
        description: 'Remarks added to application: $remarks',
        targetId: applicationId,
        targetTable: 'applications',
      );
    } catch (e) {
      debugPrint('[TPORepositoryImpl] addRoundRemarks warning: $e');
    }
  }

  @override
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? driveId,
    String? applicationId,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'drive_id': driveId,
        'application_id': applicationId,
      });
    } catch (_) {}

    // Also deliver the same message as a push notification to the student
    try {
      await _supabase.functions.invoke('send-fcm-push', body: {
        'user_ids': [userId],
        'title': title,
        'body': body,
        if (driveId != null) 'drive_id': driveId,
        if (applicationId != null) 'application_id': applicationId,
        'skip_in_app': true,
      });
    } catch (_) {}
  }

  @override
  Future<int> sendDriveDeadlineReminder({
    required String driveId,
    required String performedBy,
  }) async {
    try {
      // 1. Fetch drive info
      final driveData = await _supabase
          .from('drives')
          .select('role_title, ctc_or_stipend, end_date, eligibility_branches, eligibility_cgpa, backlog_limit, company:companies!company_id(name)')
          .eq('id', driveId)
          .maybeSingle();

      if (driveData == null) return 0;

      final roleTitle = (driveData['role_title'] as String?) ?? 'Open Role';
      final compName = (driveData['company'] is Map ? (driveData['company'] as Map)['name'] : null) ?? 'Company';
      final package = (driveData['ctc_or_stipend'] as String?) ?? '';
      final branches = (driveData['eligibility_branches'] as List?)?.cast<String>();
      final minCgpa = (driveData['eligibility_cgpa'] as num?)?.toDouble();
      final maxBacklogs = (driveData['backlog_limit'] as num?)?.toInt();

      // 2. Fetch already applied student IDs
      final appliedApps = await _supabase
          .from('applications')
          .select('student_id')
          .eq('drive_id', driveId);
      final appliedSet = (appliedApps as List)
          .map((a) => a['student_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();

      // 3. Query approved students matching department eligibility
      var query = _supabase
          .from('profiles')
          .select('id, name, email, department, cgpa, active_backlogs')
          .eq('role', 'student')
          .eq('approval_status', 'approved');

      if (branches != null && branches.isNotEmpty) {
        query = query.filter('department', 'in', branches);
      }

      final studentProfiles = await query;
      final targetStudents = <Map<String, dynamic>>[];

      for (final s in (studentProfiles as List)) {
        final sid = s['id'] as String?;
        if (sid == null || appliedSet.contains(sid)) continue;

        // Check CGPA & backlogs
        final cgpa = (s['cgpa'] as num?)?.toDouble() ?? 0.0;
        final backlogs = (s['active_backlogs'] as num?)?.toInt() ?? 0;

        if (minCgpa != null && cgpa < minCgpa) continue;
        if (maxBacklogs != null && backlogs > maxBacklogs) continue;

        targetStudents.add(s as Map<String, dynamic>);
      }

      if (targetStudents.isEmpty) return 0;

      final targetIds = targetStudents.map((s) => s['id'] as String).toList();
      const deadlineTitle = '⏳ Application Deadline Reminder';
      final deadlineBody = 'Applications for $compName ($roleTitle) close soon! Tap to submit your application.';

      // Insert in-app notifications
      for (final sid in targetIds) {
        await _supabase.from('notifications').insert({
          'user_id': sid,
          'title': deadlineTitle,
          'body': deadlineBody,
          'type': 'deadline_reminder',
          'drive_id': driveId,
        });
      }

      // Dispatch FCM Push Notification in batch
      await _supabase.functions.invoke('send-fcm-push', body: {
        'user_ids': targetIds,
        'title': deadlineTitle,
        'body': deadlineBody,
        'drive_id': driveId,
      });

      // Dispatch reminder emails
      if (_emailService != null) {
        for (final s in targetStudents) {
          final email = s['email'] as String?;
          final name = (s['name'] as String?) ?? 'Student';
          if (email != null && email.isNotEmpty) {
            _emailService!.sendReminderEmail(
              recipientEmail: email,
              studentName: name,
              reminderTitle: 'Drive Deadline Reminder: $compName',
              message: 'Applications for $compName - $roleTitle ($package) are closing soon. Please log in and submit your application before the deadline.',
              deadline: driveData['end_date'] as String?,
            );
          }
        }
      }

      return targetIds.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    List<String>? targetDepartments,
    List<String>? targetRoles,
  }) async {
    try {
      var query = _supabase.from('profiles').select('id, email, name');

      if (targetRoles != null && targetRoles.isNotEmpty) {
        query = query.filter('role', 'in', targetRoles);
      }
      if (targetDepartments != null && targetDepartments.isNotEmpty) {
        query = query.filter('department', 'in', targetDepartments);
      }

      final res = await query;
      final profiles = (res as List).cast<Map<String, dynamic>>();
      final userIds = profiles.map((p) => p['id'] as String).toList();

      if (userIds.isEmpty) return;

      for (final uid in userIds) {
        await _supabase.from('notifications').insert({
          'user_id': uid,
          'title': title,
          'body': body,
          'type': 'announcement',
        });
      }

      await _supabase.functions.invoke('send-fcm-push', body: {
        'user_ids': userIds,
        'title': title,
        'body': body,
      });
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> getStudentRoundProgress(String applicationId) async {
    final response = await _supabase
        .from('application_round_status')
        .select('*, round:drive_rounds(round_number, round_name, round_date, round_time, venue_or_link)')
        .eq('application_id', applicationId);

    return (response as List).cast<Map<String, dynamic>>();
  }
}

