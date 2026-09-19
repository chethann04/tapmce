import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/drive.dart';
import '../providers/student_drive_provider.dart';
import '../../../../core/services/email_notification_service.dart';
import '../../../../shared/presentation/widgets/animated_checkmark.dart';
import '../../../../shared/presentation/widgets/celebration_overlay.dart';

/// Full-screen drive details with eligibility check, consent, summary, and submit.
class DriveDetailsScreen extends ConsumerStatefulWidget {
  final Drive drive;
  const DriveDetailsScreen({required this.drive, super.key});

  @override
  ConsumerState<DriveDetailsScreen> createState() => _DriveDetailsScreenState();
}

class _DriveDetailsScreenState extends ConsumerState<DriveDetailsScreen> {
  bool _consentProfile = false;
  bool _consentResume = false;
  bool _consentNoWithdraw = false;
  bool _consentShare = false;
  bool _isSubmitting = false;
  bool _isAppliedState = false;

  Uint8List? _customResumeBytes;
  String? _customResumeFileName;

  Drive get _drive => widget.drive;

  // ── Eligibility computation ─────────────────────────────────────────────

  _EligibilityResult _checkEligibility(UserProfile? profile) {
    if (profile == null) {
      return const _EligibilityResult(
        eligible: false,
        checks: [],
        failureReason: 'Profile not loaded.',
      );
    }

    final checks = <_EligibilityCheck>[];

    // Profile completed
    checks.add(_EligibilityCheck(
      label: 'Profile Completed',
      passed: profile.profileCompleted,
      detail: profile.profileCompleted ? null : 'Complete your profile to apply.',
    ));

    // Faculty approved
    final approved = profile.approvalStatus == ApprovalStatus.approved;
    checks.add(_EligibilityCheck(
      label: 'Faculty Verified',
      passed: approved,
      detail: approved ? null : 'Wait for faculty coordinator approval.',
    ));

    // Resume uploaded
    final hasResume = profile.resumeUrl != null && profile.resumeUrl!.isNotEmpty;
    checks.add(_EligibilityCheck(
      label: 'Resume Uploaded',
      passed: hasResume,
      detail: hasResume ? null : 'Upload your resume to apply.',
    ));

    // CGPA
    if (_drive.cgpaCutoff > 0 && profile.cgpa != null) {
      final cgpaOk = profile.cgpa! >= _drive.cgpaCutoff;
      checks.add(_EligibilityCheck(
        label: 'CGPA ≥ ${_drive.cgpaCutoff}',
        passed: cgpaOk,
        detail: cgpaOk ? null : 'Your CGPA: ${profile.cgpa!.toStringAsFixed(2)}',
      ));
    }

    // Backlogs
    if (_drive.backlogLimit >= 0) {
      final backlogsOk = profile.activeBacklogs <= _drive.backlogLimit;
      checks.add(_EligibilityCheck(
        label: 'Backlogs ≤ ${_drive.backlogLimit}',
        passed: backlogsOk,
        detail: backlogsOk ? null : 'Active backlogs: ${profile.activeBacklogs}',
      ));
    }

    // Department / Course Code Eligibility Check
    if (_drive.eligibilityBranches.isNotEmpty) {
      final studentCode = profile.effectiveCourseCode.toUpperCase();
      final studentName = profile.effectiveCourseName;
      final deptShort = _departmentShortCode(studentName);

      final deptOk = _drive.eligibilityBranches.any((b) {
        final cleanB = b.trim().toUpperCase();
        return cleanB == studentCode ||
            cleanB == deptShort.toUpperCase() ||
            cleanB == studentName.toUpperCase();
      });

      checks.add(_EligibilityCheck(
        label: 'Course / Branch Eligible',
        passed: deptOk,
        detail: deptOk ? null : 'Your branch: $studentName ($studentCode). Required: ${_drive.eligibilityBranches.join(', ')}',
      ));
    }

    // Registration deadline
    final now = DateTime.now();
    final deadlineOk = _drive.applicationDeadline.isAfter(now);
    checks.add(_EligibilityCheck(
      label: 'Registration Open',
      passed: deadlineOk,
      detail: deadlineOk ? null : 'Registration closed on ${DateFormat('dd MMM yyyy').format(_drive.applicationDeadline)}',
    ));

    final allPassed = checks.every((c) => c.passed);
    final firstFailure = checks.firstWhere((c) => !c.passed, orElse: () => const _EligibilityCheck(label: '', passed: true));

    return _EligibilityResult(
      eligible: allPassed,
      checks: checks,
      failureReason: allPassed ? null : firstFailure.detail,
      failureLabel: allPassed ? null : firstFailure.label,
    );
  }

  String _departmentShortCode(String dept) {
    final map = {
      'Information Science & Engineering': 'IS',
      'Information Science Engineering': 'IS',
      'Computer Science & Engineering': 'CS',
      'Computer Science Engineering': 'CS',
      'Electronics & Communication Engineering': 'EC',
      'Electronics Communication Engineering': 'EC',
      'Electrical & Electronics Engineering': 'EE',
      'Electrical Electronics Engineering': 'EE',
      'Mechanical Engineering': 'ME',
      'Civil Engineering': 'CV',
    };
    return map[dept] ?? dept;
  }

  // ── Submit application ──────────────────────────────────────────────────

  Future<void> _submitApplication(UserProfile? profile) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Check System Setting: allow_multiple_offers policy
      final sysSettings = await Supabase.instance.client
          .from('system_settings')
          .select('allow_multiple_offers')
          .eq('id', 'global_config')
          .maybeSingle();

      final allowMultiple = (sysSettings?['allow_multiple_offers'] as bool?) ?? false;

      if (!allowMultiple) {
        try {
          final existingOffers = await Supabase.instance.client
              .from('offers')
              .select('id, applications!inner(student_id)')
              .eq('applications.student_id', user.id)
              .maybeSingle();

          if (existingOffers != null) {
            final appStatus = await Supabase.instance.client
                .from('applications')
                .select('status')
                .eq('student_id', user.id)
                .eq('status', 'selected')
                .maybeSingle();

            if (appStatus != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Policy Restriction: You have already accepted a placement offer. Multiple offers are not permitted.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
          }
        } catch (_) {}
      }

      // Duplicate check
      final existing = await Supabase.instance.client
          .from('applications')
          .select('id')
          .eq('student_id', user.id)
          .eq('drive_id', _drive.id)
          .maybeSingle();

      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have already applied to this drive.'), behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }

      // Upload custom resume if student picked a new file for this drive application
      String? finalResumeUrl = profile?.resumeUrl;
      if (_customResumeBytes != null && _customResumeFileName != null) {
        try {
          final fileExt = _customResumeFileName!.split('.').last;
          final storagePath = 'applications/${user.id}_${_drive.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          await Supabase.instance.client.storage
              .from('resumes')
              .uploadBinary(storagePath, _customResumeBytes!, fileOptions: const FileOptions(upsert: true));
          final publicUrl = Supabase.instance.client.storage.from('resumes').getPublicUrl(storagePath);
          finalResumeUrl = publicUrl;
        } catch (_) {}
      }

      // Insert application — place student in Round 1 by default
      Map<String, dynamic>? appResponse;
      try {
        final appInsertData = <String, dynamic>{
          'student_id': user.id,
          'drive_id': _drive.id,
          'status': 'applied',
          'current_round': 1,
        };
        if (finalResumeUrl != null) {
          appInsertData['resume_version_url'] = finalResumeUrl;
        }

        appResponse = await Supabase.instance.client
            .from('applications')
            .insert(appInsertData)
            .select('id')
            .maybeSingle();
      } catch (insertErr) {
        // Fallback without resume_version_url if database migration 00020 is not yet applied
        debugPrint('[DriveDetails] Insert with resume_version_url failed ($insertErr), retrying basic insert...');
        appResponse = await Supabase.instance.client
            .from('applications')
            .insert({
          'student_id': user.id,
          'drive_id': _drive.id,
          'status': 'applied',
          'current_round': 1,
        }).select('id').maybeSingle();
      }

      final applicationId = appResponse?['id'] as String?;

      // Create application_round_status for Round 1 so student appears in Manage Recruitment
      if (applicationId != null) {
        try {
          final firstRound = await Supabase.instance.client
              .from('drive_rounds')
              .select('id')
              .eq('drive_id', _drive.id)
              .eq('round_number', 1)
              .maybeSingle();

          if (firstRound != null) {
            await Supabase.instance.client
                .from('application_round_status')
                .upsert({
              'application_id': applicationId,
              'round_id': firstRound['id'],
              'result': 'pending',
            }, onConflict: 'application_id,round_id');
          }
        } catch (roundStatusErr) {
          debugPrint('[DriveDetails] application_round_status insert warning: $roundStatusErr');
        }
      }

      // Fetch profile for notification and success sheet display
      Map<String, dynamic>? profileMap;
      try {
        profileMap = await Supabase.instance.client
            .from('profiles')
            .select('name, email')
            .eq('id', user.id)
            .maybeSingle();

        if (profileMap != null && profileMap['email'] != null) {
          ref.read(emailNotificationServiceProvider).sendApplicationSubmittedEmail(
            recipientEmail: profileMap['email'] as String,
            studentName: (profileMap['name'] as String?) ?? 'Student',
            companyName: _drive.companyName,
            roleTitle: _drive.roleTitle,
          );
        }
      } catch (_) {}

      // ── FCM push on apply: confirmation to student + alert to TPO/admin ──
      final studentName = (profileMap?['name'] as String?) ?? 'Student';
      final pushTargets = <Map<String, dynamic>>[
        {
          'user_ids': [user.id],
          'drive_id': _drive.id,
          'title': 'Application Submitted',
          'body': 'You have applied to ${_drive.companyName} - ${_drive.roleTitle}. Good luck!',
        },
      ];
      try {
        final staffRows = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .inFilter('role', ['tpo', 'admin']);
        final staffIds = (staffRows as List).map((r) => r['id'] as String).toList();
        if (staffIds.isNotEmpty) {
          pushTargets.add({
            'user_ids': staffIds,
            'drive_id': _drive.id,
            'title': 'New Application',
            'body': '$studentName applied to ${_drive.companyName} - ${_drive.roleTitle}',
          });
        }
      } catch (e) {
        debugPrint('[DriveDetails] Staff lookup warning: $e');
      }

      for (final target in pushTargets) {
        try {
          await Supabase.instance.client.functions.invoke('send-fcm-push', body: target);
        } catch (e) {
          debugPrint('[DriveDetails] FCM push warning: $e');
        }
      }

      // Refresh providers
      ref.invalidate(studentApplicationsProvider);
      ref.invalidate(studentEligibleDrivesProvider);
      ref.invalidate(studentAppliedDriveIdsProvider);

      if (mounted) {
        setState(() {
          _isAppliedState = true;
        });
        CelebrationOverlay.show(context);
        _showSuccessSheet(null);
      }
    } catch (e) {
      debugPrint('[DriveDetails] Application submit failed: $e');
      final errorMsg = e.toString().contains('already applied')
          ? 'You have already registered for this drive.'
          : (e is PostgrestException ? e.message : 'Unable to submit application: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessSheet(UserProfile? profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const ContinuousRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppShapes.radiusHero)),
      ),
      builder: (ctx) => _SuccessSheet(drive: _drive, profile: profile),
    );
  }

  bool get _consentAllChecked => _consentProfile && _consentResume && _consentNoWithdraw && _consentShare;

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final profileAsync = ref.watch(authNotifierProvider);
    final profile = profileAsync.valueOrNull;
    final eligibility = _checkEligibility(profile);

    final dbApplied = ref.watch(studentAppliedDriveIdsProvider).contains(_drive.id);
    final alreadyApplied = _isAppliedState || dbApplied;

    final daysLeft = _drive.applicationDeadline.difference(DateTime.now()).inDays;
    final deadlineLabel = daysLeft > 0 ? '$daysLeft days left' : 'Closing today';
    final statusColor = _drive.status == 'open' ? brandTheme.statusShortlisted : brandTheme.textMuted;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/student');
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_drive.companyName, style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/student');
              }
            },
          ),
        ),
        body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          top: AppSpacing.sp3,
          left: AppSpacing.sp5,
          right: AppSpacing.sp5,
          bottom: 100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Company Header ──────────────────────────────────────────
            _sectionCard(
              theme: theme,
              brandTheme: brandTheme,
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: brandTheme.brassGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        _drive.companyName.substring(0, _drive.companyName.length.clamp(0, 2)).toUpperCase(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: brandTheme.onBrass),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sp3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_drive.companyName, style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(_drive.roleTitle, style: GoogleFonts.inter(fontSize: 14, color: brandTheme.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(_drive.status.toUpperCase(), style: GoogleFonts.ibmPlexMono(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sp3),

            // ── Package ─────────────────────────────────────────────────
            if (_drive.ctcOrStipend.isNotEmpty)
              _infoRowCard(Icons.payments_outlined, 'Package', _drive.ctcOrStipend, brandTheme, theme),
            const SizedBox(height: AppSpacing.sp3),

            // ── Description ─────────────────────────────────────────────
            if (_drive.jobDescription.isNotEmpty) ...[
              _sectionCard(
                theme: theme,
                brandTheme: brandTheme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Description', brandTheme),
                    const SizedBox(height: AppSpacing.sp2),
                    Text(_drive.jobDescription, style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sp3),
            ],

            // ── Eligibility ─────────────────────────────────────────────
            _sectionCard(
              theme: theme,
              brandTheme: brandTheme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Eligibility', brandTheme),
                  const SizedBox(height: AppSpacing.sp3),
                  _eligibilityRow('Minimum CGPA', _drive.cgpaCutoff > 0 ? '${_drive.cgpaCutoff}' : 'No requirement', brandTheme),
                  _eligibilityRow('Max Backlogs', '${_drive.backlogLimit}', brandTheme),
                  if (_drive.eligibilityBranches.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sp2),
                    Text('Eligible Branches', style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
                    const SizedBox(height: AppSpacing.sp2),
                    Wrap(
                      spacing: AppSpacing.sp2,
                      runSpacing: AppSpacing.sp2,
                      children: _drive.eligibilityBranches.map((b) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: brandTheme.brassSoft.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(b, style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary)),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sp3),

            // ── Timeline ────────────────────────────────────────────────
            _sectionCard(
              theme: theme,
              brandTheme: brandTheme,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Timeline', brandTheme),
                  const SizedBox(height: AppSpacing.sp3),
                  _timelineRow(Icons.calendar_today_rounded, 'Registration Opens', DateFormat('dd MMM yyyy').format(_drive.applicationDeadline.subtract(const Duration(days: 14))), brandTheme),
                  _timelineRow(Icons.event_rounded, 'Registration Closes', DateFormat('dd MMM yyyy').format(_drive.applicationDeadline), brandTheme),
                  const SizedBox(height: AppSpacing.sp2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(deadlineLabel, style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                  ),
                ],
              ),
            ),

            if (!alreadyApplied) ...[
              const SizedBox(height: AppSpacing.sp4),

              // ── Eligibility Verification ──────────────────────────────
              _sectionCard(
                theme: theme,
                brandTheme: brandTheme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Eligibility Check', brandTheme),
                    const SizedBox(height: AppSpacing.sp3),
                    ...eligibility.checks.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            c.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 18,
                            color: c.passed ? brandTheme.statusShortlisted : brandTheme.statusRejected,
                          ),
                          const SizedBox(width: AppSpacing.sp2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                                if (c.detail != null)
                                  Text(c.detail!, style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                    const SizedBox(height: AppSpacing.sp3),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sp3),
                      decoration: BoxDecoration(
                        color: eligibility.eligible
                            ? brandTheme.statusShortlisted.withValues(alpha: 0.1)
                            : brandTheme.statusRejected.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                      ),
                      child: Text(
                        eligibility.eligible
                            ? 'You are eligible to apply.'
                            : eligibility.failureReason ?? 'Not eligible.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: eligibility.eligible ? brandTheme.statusShortlisted : brandTheme.statusRejected,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              if (eligibility.eligible) ...[
                const SizedBox(height: AppSpacing.sp3),

                // ── Consent ─────────────────────────────────────────────
                _sectionCard(
                  theme: theme,
                  brandTheme: brandTheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Consent', brandTheme),
                      const SizedBox(height: AppSpacing.sp3),
                      _consentTile('My profile is correct.', _consentProfile, (v) => setState(() => _consentProfile = v)),
                      _consentTile('My uploaded resume is final.', _consentResume, (v) => setState(() => _consentResume = v)),
                      _consentTile('I understand I cannot withdraw after the deadline.', _consentNoWithdraw, (v) => setState(() => _consentNoWithdraw = v)),
                      _consentTile('I agree to share my profile with the company.', _consentShare, (v) => setState(() => _consentShare = v)),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.sp3),

                // ── Summary ─────────────────────────────────────────────
                _sectionCard(
                  theme: theme,
                  brandTheme: brandTheme,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Application Summary', brandTheme),
                      const SizedBox(height: AppSpacing.sp3),
                      _summaryRow('Company', _drive.companyName, brandTheme),
                      _summaryRow('Role', _drive.roleTitle, brandTheme),
                      _summaryRow(
                        'Resume',
                        _customResumeFileName ?? (profile?.resumeUrl != null ? _extractFileName(profile!.resumeUrl!) : 'Default Profile Resume'),
                        brandTheme,
                      ),
                      const SizedBox(height: 8),
                      // Option to change resume for this application
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                            withData: true,
                          );
                          if (result != null && result.files.isNotEmpty) {
                            final file = result.files.first;
                            if (file.bytes != null) {
                              setState(() {
                                _customResumeBytes = file.bytes;
                                _customResumeFileName = file.name;
                              });
                            }
                          }
                        },
                        icon: Icon(Icons.upload_file_rounded, size: 16, color: brandTheme.brassPrimary),
                        label: Text(
                          _customResumeFileName != null ? 'Change Attached Resume' : 'Attach Custom Resume (PDF)',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: brandTheme.brassPrimary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _summaryRow('CGPA', profile?.cgpa?.toStringAsFixed(2) ?? '—', brandTheme),
                      _summaryRow('Department', profile?.department ?? '—', brandTheme),
                      _summaryRow('Semester', profile?.semester?.toString() ?? '—', brandTheme),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),

      // ── Bottom bar ──────────────────────────────────────────────────────
      bottomSheet: Container(
        padding: EdgeInsets.only(
          left: AppSpacing.sp5,
          right: AppSpacing.sp5,
          top: AppSpacing.sp3,
          bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sp3,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: brandTheme.cardBorder)),
        ),
        child: alreadyApplied
            ? GestureDetector(
                onTap: () {
                  // Return to the previous screen (dashboard/eligible drives)
                  // instead of resetting the whole navigation stack.
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/student');
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: brandTheme.brassGradient,
                    borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                    boxShadow: [
                      BoxShadow(
                        color: brandTheme.brassPrimary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timeline_rounded, size: 18, color: brandTheme.onBrass),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'View Recruitment Progress',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: brandTheme.onBrass,
                              ),
                            ),
                            Text(
                              'See your recruitment journey',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: brandTheme.onBrass.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: brandTheme.onBrass.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(color: brandTheme.cardBorder),
                          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                        ),
                        child: Center(
                          child: Text('Back', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: brandTheme.textMuted)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sp3),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: (eligibility.eligible && _consentAllChecked && !_isSubmitting)
                          ? () => _submitApplication(profile)
                          : null,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: (eligibility.eligible && _consentAllChecked) ? brandTheme.brassGradient : null,
                          color: (eligibility.eligible && _consentAllChecked) ? null : brandTheme.cardBorder,
                          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                        ),
                        child: Center(
                          child: _isSubmitting
                              ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: brandTheme.onBrass))
                              : Text('Apply Now', style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: (eligibility.eligible && _consentAllChecked) ? brandTheme.onBrass : brandTheme.textMuted,
                                )),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ));
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionCard({required ThemeData theme, required AppBrandTheme brandTheme, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text, AppBrandTheme brandTheme) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w600, color: brandTheme.textMuted, letterSpacing: 0.5),
    );
  }

  Widget _infoRowCard(IconData icon, String label, String value, AppBrandTheme brandTheme, ThemeData theme) {
    return _sectionCard(
      theme: theme,
      brandTheme: brandTheme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: brandTheme.brassPrimary),
          const SizedBox(width: AppSpacing.sp2),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
          const SizedBox(width: AppSpacing.sp2),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _eligibilityRow(String label, String value, AppBrandTheme brandTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 16, color: brandTheme.textMuted),
          const SizedBox(width: AppSpacing.sp2),
          Expanded(
            child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
          ),
          const SizedBox(width: AppSpacing.sp2),
          Flexible(
            child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _timelineRow(IconData icon, String label, String value, AppBrandTheme brandTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: brandTheme.brassPrimary),
          const SizedBox(width: AppSpacing.sp2),
          Expanded(
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
          ),
          const SizedBox(width: AppSpacing.sp2),
          Flexible(
            child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _consentTile(String text, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: Theme.of(context).extension<AppBrandTheme>()!.brassPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, AppBrandTheme brandTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
          ),
          const SizedBox(width: AppSpacing.sp2),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  String _extractFileName(String url) {
    try {
      final clean = url.split('?').first;
      final segments = clean.split('/');
      return Uri.decodeComponent(segments.last);
    } catch (_) {
      return 'Resume';
    }
  }
}

// ── Supporting classes ────────────────────────────────────────────────────

class _EligibilityCheck {
  final String label;
  final bool passed;
  final String? detail;
  const _EligibilityCheck({required this.label, required this.passed, this.detail});
}

class _EligibilityResult {
  final bool eligible;
  final List<_EligibilityCheck> checks;
  final String? failureReason;
  final String? failureLabel;
  const _EligibilityResult({required this.eligible, required this.checks, this.failureReason, this.failureLabel});
}

// ── Success Bottom Sheet ──────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  final Drive drive;
  final UserProfile? profile;
  const _SuccessSheet({required this.drive, this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.sp5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: brandTheme.cardBorder, borderRadius: BorderRadius.circular(100))),
            const SizedBox(height: AppSpacing.sp6),
            AnimatedCheckmark(
              size: 64,
              color: brandTheme.statusShortlisted,
            ),
            const SizedBox(height: AppSpacing.sp4),
            Text('Application Submitted', style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sp2),
            Text('Your application has been recorded.', style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
            const SizedBox(height: AppSpacing.sp5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sp4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                border: Border.all(color: brandTheme.cardBorder),
              ),
              child: Column(
                children: [
                  _summaryRow('Company', drive.companyName, brandTheme),
                  _summaryRow('Role', drive.roleTitle, brandTheme),
                  _summaryRow('Applied On', DateFormat('dd MMM yyyy').format(DateTime.now()), brandTheme),
                  _summaryRow('Status', 'Applied', brandTheme),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sp5),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/student');
                      }
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: brandTheme.cardBorder),
                        borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                      ),
                      child: Center(
                        child: Text('Dashboard', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: brandTheme.textMuted)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sp3),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/student');
                      }
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: brandTheme.brassGradient,
                        borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                      ),
                      child: Center(
                        child: Text('View Applications', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: brandTheme.onBrass)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, AppBrandTheme brandTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
          ),
          const SizedBox(width: AppSpacing.sp2),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
