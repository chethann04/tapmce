import 'dart:io';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/tpo_provider.dart';
import '../../../student/domain/entities/drive.dart';
import '../../../student/presentation/providers/student_drive_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/floating_pill_nav_bar.dart';
import '../../../../shared/presentation/widgets/skeleton_loader.dart';
import '../../../../shared/presentation/widgets/state_block_widget.dart';
import '../../../../shared/presentation/widgets/status_thread_widget.dart';
import '../../../../shared/presentation/widgets/subtle_divider.dart';
import '../../../../shared/presentation/widgets/app_refresh_indicator.dart';
import '../../../../shared/presentation/widgets/interactive_feedback.dart';
import '../../../../core/theme/app_motion.dart';
import '../widgets/drive_qr_code_modal.dart';
import 'drive_creation_wizard.dart';
import 'tpo_profile_screen.dart';
import '../../../../shared/presentation/widgets/profile_avatar.dart';

class TpoDashboardScreen extends ConsumerStatefulWidget {
  const TpoDashboardScreen({super.key});

  @override
  ConsumerState<TpoDashboardScreen> createState() => _TpoDashboardScreenState();
}

class _TpoDashboardScreenState extends ConsumerState<TpoDashboardScreen> {
  bool _isExportingStudents = false;

  Future<void> _exportRegisteredStudentsExcel(BuildContext context) async {
    if (_isExportingStudents) return;
    setState(() => _isExportingStudents = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Generating Registered Students Excel Report...',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('role', 'student')
          .order('department', ascending: true)
          .order('usn', ascending: true);

      final students = (response as List).cast<Map<String, dynamic>>();
      if (students.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No registered students found to export.')),
        );
        return;
      }

      final excel = excel_pkg.Excel.createExcel();
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final sheet = excel['Registered Students'];
      excel.setDefaultSheet('Registered Students');

      // Title & Metadata
      sheet.appendRow([
        excel_pkg.TextCellValue('Malnad College of Engineering — Placement Cell'),
      ]);
      sheet.appendRow([
        excel_pkg.TextCellValue('Official Registered Students Master Report'),
      ]);
      sheet.appendRow([
        excel_pkg.TextCellValue('Total Registered Students: ${students.length}'),
        excel_pkg.TextCellValue('Exported At: ${DateTime.now().toLocal().toString().split('.')[0]}'),
      ]);
      sheet.appendRow([]); // Empty spacer row

      // Headers
      final headers = <excel_pkg.CellValue>[
        excel_pkg.TextCellValue('Sl No'),
        excel_pkg.TextCellValue('USN / Roll No'),
        excel_pkg.TextCellValue('Full Name'),
        excel_pkg.TextCellValue('Email'),
        excel_pkg.TextCellValue('Phone Number'),
        excel_pkg.TextCellValue('Department'),
        excel_pkg.TextCellValue('Course Code'),
        excel_pkg.TextCellValue('Course Name'),
        excel_pkg.TextCellValue('Semester'),
        excel_pkg.TextCellValue('Section'),
        excel_pkg.TextCellValue('Batch'),
        excel_pkg.TextCellValue('Admission Year'),
        excel_pkg.TextCellValue('Graduation Year'),
        excel_pkg.TextCellValue('10th (SSLC) %'),
        excel_pkg.TextCellValue('12th / Diploma %'),
        excel_pkg.TextCellValue('CGPA'),
        excel_pkg.TextCellValue('Active Backlogs'),
        excel_pkg.TextCellValue('Verification Status'),
        excel_pkg.TextCellValue('Consent Status'),
        excel_pkg.TextCellValue('Profile Completed'),
        excel_pkg.TextCellValue('Email Verified'),
        excel_pkg.TextCellValue('Registration Date'),
      ];
      sheet.appendRow(headers);

      int slNo = 1;
      final deptStats = <String, Map<String, int>>{};

      for (final s in students) {
        final dept = (s['department'] as String?) ?? 'Unassigned';
        final courseCode = (s['verified_course_code'] ?? s['detected_course_code'] ?? '') as String;
        final courseName = (s['verified_course_name'] ?? s['detected_course_name'] ?? dept) as String;
        final approvalStatus = (s['approval_status'] as String?)?.toUpperCase() ?? 'PENDING';
        final consentStatus = (s['consent_status'] as String?)?.replaceAll('_', ' ').toUpperCase() ?? 'NOT SET';
        final profileCompleted = (s['profile_completed'] as bool? ?? false) ? 'YES' : 'NO';
        final emailVerified = (s['email_verified'] as bool? ?? false) ? 'YES' : 'NO';
        final createdAt = s['created_at'] != null ? s['created_at'].toString().split('T').first : 'N/A';

        deptStats.putIfAbsent(dept, () => {'total': 0, 'approved': 0, 'pending': 0, 'rejected': 0});
        deptStats[dept]!['total'] = (deptStats[dept]!['total'] ?? 0) + 1;
        if (approvalStatus == 'APPROVED') {
          deptStats[dept]!['approved'] = (deptStats[dept]!['approved'] ?? 0) + 1;
        } else if (approvalStatus == 'REJECTED') {
          deptStats[dept]!['rejected'] = (deptStats[dept]!['rejected'] ?? 0) + 1;
        } else {
          deptStats[dept]!['pending'] = (deptStats[dept]!['pending'] ?? 0) + 1;
        }

        sheet.appendRow([
          excel_pkg.IntCellValue(slNo++),
          excel_pkg.TextCellValue((s['usn'] as String?) ?? 'N/A'),
          excel_pkg.TextCellValue((s['name'] as String?) ?? 'N/A'),
          excel_pkg.TextCellValue((s['email'] as String?) ?? 'N/A'),
          excel_pkg.TextCellValue((s['phone'] as String?) ?? 'N/A'),
          excel_pkg.TextCellValue(dept),
          excel_pkg.TextCellValue(courseCode),
          excel_pkg.TextCellValue(courseName),
          s['semester'] != null ? excel_pkg.IntCellValue(s['semester'] as int) : excel_pkg.TextCellValue('N/A'),
          excel_pkg.TextCellValue((s['section'] as String?) ?? 'N/A'),
          excel_pkg.TextCellValue((s['batch'] as String?) ?? 'N/A'),
          s['admission_year'] != null ? excel_pkg.IntCellValue(s['admission_year'] as int) : excel_pkg.TextCellValue('N/A'),
          s['graduation_year'] != null ? excel_pkg.IntCellValue(s['graduation_year'] as int) : excel_pkg.TextCellValue('N/A'),
          s['tenth_percent'] != null ? excel_pkg.DoubleCellValue((s['tenth_percent'] as num).toDouble()) : excel_pkg.TextCellValue('N/A'),
          s['twelfth_or_diploma_percent'] != null ? excel_pkg.DoubleCellValue((s['twelfth_or_diploma_percent'] as num).toDouble()) : excel_pkg.TextCellValue('N/A'),
          s['cgpa'] != null ? excel_pkg.DoubleCellValue((s['cgpa'] as num).toDouble()) : excel_pkg.TextCellValue('N/A'),
          excel_pkg.IntCellValue(s['active_backlogs'] as int? ?? 0),
          excel_pkg.TextCellValue(approvalStatus),
          excel_pkg.TextCellValue(consentStatus),
          excel_pkg.TextCellValue(profileCompleted),
          excel_pkg.TextCellValue(emailVerified),
          excel_pkg.TextCellValue(createdAt),
        ]);
      }

      // Sheet 2: Department Summary Breakdown
      final summarySheet = excel['Department Breakdown'];
      summarySheet.appendRow([
        excel_pkg.TextCellValue('Department Summary Breakdown'),
      ]);
      summarySheet.appendRow([]);
      summarySheet.appendRow([
        excel_pkg.TextCellValue('Department'),
        excel_pkg.TextCellValue('Total Registered'),
        excel_pkg.TextCellValue('Approved'),
        excel_pkg.TextCellValue('Pending Verification'),
        excel_pkg.TextCellValue('Rejected'),
      ]);

      for (final entry in deptStats.entries) {
        summarySheet.appendRow([
          excel_pkg.TextCellValue(entry.key),
          excel_pkg.IntCellValue(entry.value['total'] ?? 0),
          excel_pkg.IntCellValue(entry.value['approved'] ?? 0),
          excel_pkg.IntCellValue(entry.value['pending'] ?? 0),
          excel_pkg.IntCellValue(entry.value['rejected'] ?? 0),
        ]);
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
        final filePath = '${directory.path}/MCE_Registered_Students_$timestamp.xlsx';
        await File(filePath).writeAsBytes(fileBytes, flush: true);

        final result = await Share.shareXFiles(
          [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          text: 'MCE Placement Cell — Registered Students Excel Export ($timestamp)',
          subject: 'Registered Students Excel Report',
        );

        if (result.status == ShareResultStatus.success) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('✅ Registered students Excel exported successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Error exporting Excel report: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExportingStudents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentNavIndex = ref.watch(tpoDashboardTabProvider);
    final profileAsync = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    final navDestinations = [
      const NavDestinationItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: 'Overview',
      ),
      const NavDestinationItem(
        icon: Icons.business_center_outlined,
        selectedIcon: Icons.business_center_rounded,
        label: 'Drives',
      ),
      const NavDestinationItem(
        icon: Icons.person_add_alt_outlined,
        selectedIcon: Icons.person_add_alt_rounded,
        label: 'Faculty',
      ),
      const NavDestinationItem(
        icon: Icons.assignment_turned_in_outlined,
        selectedIcon: Icons.assignment_turned_in_rounded,
        label: 'Offers',
      ),
      const NavDestinationItem(
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: 'Profile',
      ),
    ];

    return PopScope(
      canPop: currentNavIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentNavIndex != 0) {
          ref.read(tpoDashboardTabProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: profileAsync.when(
                data: (profile) => AnimatedSwitcher(
                  duration: AppMotion.normal,
                  switchInCurve: AppMotion.easeOutCubic,
                  switchOutCurve: AppMotion.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<int>(currentNavIndex),
                    child: _buildTabContent(currentNavIndex, profile?.fullName ?? 'TPO Officer', brandTheme, theme),
                  ),
                ),
                loading: () => Padding(
                  padding: const EdgeInsets.only(top: 80, left: 16, right: 16),
                  child: Column(
                    children: const [
                      SkeletonCardRow(),
                      SkeletonCardRow(),
                    ],
                  ),
                ),
                error: (e, _) => StateBlockWidget(
                  icon: Icons.error_outline_rounded,
                  title: "Couldn't load TPO dashboard",
                  message: e.toString(),
                  isError: true,
                ),
              ),
            ),

            // Floating FAB thumb ergonomic position (Drive Management Tab Only)
            if (currentNavIndex == 1)
              Positioned(
                right: AppSpacing.sp5,
                bottom: 104,
                child: InteractiveFeedback(
                  onTap: () => context.push('/tpo/create-drive'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: brandTheme.brassGradient,
                      borderRadius: BorderRadius.circular(AppShapes.radiusFab),
                      boxShadow: brandTheme.shadow2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, color: brandTheme.onBrass, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'New Drive',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: brandTheme.onBrass,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Floating FAB thumb ergonomic position (Faculty Coordinator Tab Only)
            if (currentNavIndex == 2)
              Positioned(
                right: AppSpacing.sp5,
                bottom: 104,
                child: InteractiveFeedback(
                  onTap: () => context.push('/tpo/appoint-faculty'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: brandTheme.brassGradient,
                      borderRadius: BorderRadius.circular(AppShapes.radiusFab),
                      boxShadow: brandTheme.shadow2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded, color: brandTheme.onBrass, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'New Faculty Coordinator',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: brandTheme.onBrass,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Floating Pill Nav Bar
            FloatingPillNavBar(
              selectedIndex: currentNavIndex,
              onDestinationSelected: (index) => ref.read(tpoDashboardTabProvider.notifier).state = index,
              items: navDestinations,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex, String name, AppBrandTheme brandTheme, ThemeData theme) {
    switch (tabIndex) {
      case 0:
        return _overviewTab(context, ref, name, brandTheme, theme);
      case 1:
        return _drivesManagementTab(ref, brandTheme, theme);
      case 2:
        return _appointFacultyTab(ref, brandTheme, theme);
      case 3:
        return _offersAndRoundsTab(ref, brandTheme, theme);
      case 4:
        return TpoProfileScreen(profile: ref.watch(authNotifierProvider).valueOrNull);
      default:
        return _overviewTab(context, ref, name, brandTheme, theme);
    }
  }

  Widget _overviewTab(BuildContext context, WidgetRef ref, String name, AppBrandTheme brandTheme, ThemeData theme) {
    final drivesAsync = ref.watch(tpoDrivesProvider);
    final applicantsAsync = ref.watch(tpoApplicantCountProvider);
    final offersAsync = ref.watch(tpoOffersCountProvider);
    final topPadding = MediaQuery.of(context).padding.top + AppSpacing.sp3;

    return AppRefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.refresh(tpoDrivesProvider.future),
          ref.refresh(tpoApplicantCountProvider.future),
          ref.refresh(tpoOffersCountProvider.future),
          ref.refresh(tpoRegisteredStudentsCountProvider.future),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: topPadding,
          left: AppSpacing.sp5,
          right: AppSpacing.sp5,
          bottom: 170,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        text: 'Welcome, ',
                        style: GoogleFonts.fraunces(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text: name.split(' ').first,
                            style: GoogleFonts.fraunces(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: brandTheme.brassPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '2026-27 Academic Cycle · Placement Cell',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.logout_rounded, size: 22, color: brandTheme.textMuted),
                tooltip: 'Sign Out',
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sp5),

          drivesAsync.when(
            data: (drives) {
              final activeDrivesCount = drives.length;
              final applicantsCount = applicantsAsync.valueOrNull ?? 0;
              final offersCount = offersAsync.valueOrNull ?? 0;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bento Primary Tile (B1 - 1.3fr) -> Jump to Drives Tab
                    Expanded(
                      flex: 13,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppShapes.radiusHero),
                        onTap: () => ref.read(tpoDashboardTabProvider.notifier).state = 1,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 170),
                          padding: const EdgeInsets.all(AppSpacing.sp5),
                          decoration: ShapeDecoration(
                            color: theme.colorScheme.surface,
                            shape: ContinuousRectangleBorder(
                              borderRadius: BorderRadius.circular(AppShapes.radiusHero),
                              side: BorderSide(color: brandTheme.cardBorder),
                            ),
                            shadows: brandTheme.shadow2,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$activeDrivesCount',
                                style: GoogleFonts.fraunces(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  color: brandTheme.brassPrimary,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'Active Drives',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: brandTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 12, color: brandTheme.brassPrimary),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sp3),

                    // Bento Secondary Stat Tiles (B2 & B3 - 1.0fr Stack)
                    Expanded(
                      flex: 10,
                      child: Column(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                              onTap: () => ref.read(tpoDashboardTabProvider.notifier).state = 1,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: ShapeDecoration(
                                  color: theme.colorScheme.surface,
                                  shape: ContinuousRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                                    side: BorderSide(color: brandTheme.cardBorder),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$applicantsCount',
                                      style: GoogleFonts.fraunces(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Applicants',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: brandTheme.textMuted,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sp2),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                              onTap: () => ref.read(tpoDashboardTabProvider.notifier).state = 3,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: ShapeDecoration(
                                  color: theme.colorScheme.surface,
                                  shape: ContinuousRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                                    side: BorderSide(color: brandTheme.cardBorder),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$offersCount',
                                      style: GoogleFonts.fraunces(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: brandTheme.statusShortlisted,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          'Offers',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: brandTheme.textMuted,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_forward_rounded, size: 10, color: brandTheme.statusShortlisted),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SkeletonCardRow(),
            error: (err, _) => StateBlockWidget(
              icon: Icons.error_outline_rounded,
              title: "Notice",
              message: "Unable to refresh active statistics: ${err.toString()}",
            ),
          ),
          const SizedBox(height: AppSpacing.sp4),

          // Registered Students Master Excel Export Quick Action
          ref.watch(tpoRegisteredStudentsCountProvider).when(
            data: (registeredCount) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: ShapeDecoration(
                color: theme.colorScheme.surface,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                  side: BorderSide(color: brandTheme.cardBorder),
                ),
                shadows: brandTheme.shadow1,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D6F42).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1D6F42).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: Color(0xFF22C55E), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$registeredCount Registered Students',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.fraunces(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Export master database (.xlsx)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: brandTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1D6F42),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _isExportingStudents ? null : () => _exportRegisteredStudentsExcel(context),
                    icon: _isExportingStudents
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.file_download_rounded, size: 14),
                    label: Text(
                      _isExportingStudents ? 'Exporting...' : 'Export',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.sp6),

          Text(
            'LIVE DRIVE STATUS OVERVIEW',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.08,
              color: brandTheme.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sp3),

          drivesAsync.when(
            data: (drives) {
              if (drives.isEmpty) {
                return StateBlockWidget(
                  icon: Icons.business_center_outlined,
                  title: 'No placement drives active',
                  message: 'Create your first campus recruitment drive using the New Drive button.',
                );
              }
              return Column(
                children: drives.map((drive) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sp3),
                    child: _driveCard(
                      drive,
                      brandTheme,
                      theme,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => Column(
              children: const [
                SkeletonCardRow(),
                SkeletonCardRow(),
              ],
            ),
            error: (err, _) => StateBlockWidget(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load drives',
              message: err.toString(),
              isError: true,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _drivesManagementTab(WidgetRef ref, AppBrandTheme brandTheme, ThemeData theme) {
    final drivesAsync = ref.watch(tpoDrivesProvider);
    final applicantCountsAsync = ref.watch(tpoDriveApplicantCountsProvider);
    final applicantCounts = applicantCountsAsync.valueOrNull ?? {};

    return AppRefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.refresh(tpoDrivesProvider.future),
          ref.refresh(tpoDriveApplicantCountsProvider.future),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + AppSpacing.sp4,
          left: AppSpacing.sp5,
          right: AppSpacing.sp5,
          bottom: 170,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Drive Management', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sp4),

          drivesAsync.when(
            data: (drives) {
              if (drives.isEmpty) {
                return StateBlockWidget(
                  icon: Icons.work_off_outlined,
                  title: 'No drives created',
                  message: 'Tap New Drive to create a recruitment drive.',
                );
              }
              return Column(
                children: drives.map((drive) {
                  final isDriveClosed = drive.isClosed;
                  final statusLower = isDriveClosed ? 'completed' : (drive.isUpcoming ? 'upcoming' : 'active');
                  Color statusBg = brandTheme.brassSoft;
                  Color statusText = brandTheme.brassPrimary;
                  if (statusLower == 'active') {
                    statusBg = Colors.greenAccent.withValues(alpha: 0.15);
                    statusText = Colors.greenAccent;
                  } else if (statusLower == 'completed' || isDriveClosed) {
                    statusBg = Colors.blueAccent.withValues(alpha: 0.15);
                    statusText = Colors.blueAccent;
                  }

                  final branches = drive.eligibilityBranches.isNotEmpty
                      ? drive.eligibilityBranches
                      : ['ALL'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sp4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: brandTheme.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header Row with Company & Status Pill
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      drive.companyName.isNotEmpty ? drive.companyName : 'Company',
                                      style: GoogleFonts.fraunces(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusText.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      isDriveClosed ? 'CLOSED' : (drive.isUpcoming ? 'UPCOMING' : 'ACTIVE'),
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        color: statusText,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                drive.roleTitle,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: brandTheme.brassPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(Icons.payments_outlined, size: 14, color: brandTheme.textMuted),
                                  Text(
                                    'Package: ${drive.ctcOrStipend}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Icon(Icons.event_outlined, size: 14, color: brandTheme.textMuted),
                                  Text(
                                    'Deadline: ${drive.applicationDeadline.day}/${drive.applicationDeadline.month}/${drive.applicationDeadline.year}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: brandTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Branch Tags Row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: branches.map((b) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: brandTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: brandTheme.cardBorder),
                              ),
                              child: Text(
                                b,
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: brandTheme.brassPrimary,
                                ),
                              ),
                            )).toList(),
                          ),
                        ),

                        const SizedBox(height: 12),
                        const SubtleDivider(height: 1),

                        // Action Bar: View Details, Applied, Manage Rounds, & Edit Drive
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _showDriveDetailsModal(drive, brandTheme, theme),
                                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 18, color: brandTheme.brassPrimary),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Details',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: brandTheme.brassPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(width: 1, height: 32, color: brandTheme.cardBorder),
                            Expanded(
                              child: InkWell(
                                onTap: () => _showApplicantsSheet(drive, brandTheme, theme),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.people_outline_rounded, size: 18, color: brandTheme.statusShortlisted),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Applied (${applicantCounts[drive.id] ?? 0})',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: brandTheme.statusShortlisted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(width: 1, height: 32, color: brandTheme.cardBorder),
                            Expanded(
                              child: InkWell(
                                onTap: () => context.push('/tpo/round-management', extra: drive),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_circle_outline_rounded, size: 18, color: brandTheme.statusPending),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Recruit',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: brandTheme.statusPending,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(width: 1, height: 32, color: brandTheme.cardBorder),
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DriveCreationWizard(driveToEdit: drive),
                                  ),
                                ),
                                borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined, size: 18, color: brandTheme.brassPrimary),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Edit',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: brandTheme.brassPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SkeletonCardRow(),
            error: (e, _) => StateBlockWidget(
              icon: Icons.error_outline_rounded,
              title: 'Error loading drives',
              message: e.toString(),
              isError: true,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _appointFacultyTab(WidgetRef ref, AppBrandTheme brandTheme, ThemeData theme) {
    final coordinatorsAsync = ref.watch(facultyCoordinatorsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.sp4,
        left: AppSpacing.sp5,
        right: AppSpacing.sp5,
        bottom: 170,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Faculty Coordinator Appointment', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Appointed department leads for student verification queues', style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
          const SizedBox(height: AppSpacing.sp5),

          coordinatorsAsync.when(
            data: (coordinators) {
              if (coordinators.isEmpty) {
                return StateBlockWidget(
                  icon: Icons.person_add_alt_rounded,
                  title: 'No coordinators appointed',
                  message: 'Tap "+ New Faculty Coordinator" to appoint an existing faculty member.',
                );
              }
              return Column(
                children: coordinators.map((coord) {
                  final profile = coord['profile'] as Map<String, dynamic>? ?? {};
                  final name = profile['name'] as String? ?? 'Faculty Member';
                  final email = profile['email'] as String? ?? 'No email';
                  final dept = coord['department'] as String? ?? 'General';
                  final createdAtStr = coord['created_at'] as String?;
                  final dateStr = createdAtStr != null
                      ? DateTime.tryParse(createdAtStr)?.toIso8601String().split('T').first ?? ''
                      : '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sp3),
                    padding: const EdgeInsets.all(AppSpacing.sp4),
                    decoration: ShapeDecoration(
                      color: theme.colorScheme.surface,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                        side: BorderSide(color: brandTheme.cardBorder),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ProfileAvatar(
                              imageUrl: (profile['photo_url'] ?? profile['avatar_url']) as String?,
                              name: name,
                              size: ProfileAvatarSize.medium,
                              showBorder: true,
                              borderColor: brandTheme.brassPrimary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: brandTheme.brassSoft,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: brandTheme.brassPrimary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.apartment_rounded, size: 14, color: brandTheme.brassPrimary),
                                  const SizedBox(width: 6),
                                  Text(
                                    dept,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary),
                                  ),
                                ],
                              ),
                            ),
                            if (dateStr.isNotEmpty)
                              Text(
                                'Appointed: $dateStr',
                                style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SkeletonCardRow(),
            error: (e, _) => StateBlockWidget(
              icon: Icons.error_outline_rounded,
              title: 'Error loading coordinators',
              message: e.toString(),
              isError: true,
            ),
          ),
        ],
      ),
    );
  }


  Widget _offersAndRoundsTab(WidgetRef ref, AppBrandTheme brandTheme, ThemeData theme) {
    final drivesAsync = ref.watch(tpoDrivesProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.sp4,
        left: AppSpacing.sp5,
        right: AppSpacing.sp5,
        bottom: 170,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Offers & Round Management', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Change drive status, initiate rounds & upload shortlists', style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
          const SizedBox(height: AppSpacing.sp5),

          drivesAsync.when(
            data: (drives) {
              if (drives.isEmpty) {
                return StateBlockWidget(
                  icon: Icons.assignment_turned_in_rounded,
                  title: 'No drives available',
                  message: 'Create a recruitment drive first to manage rounds and update status.',
                );
              }
              return Column(
                children: drives.map((drive) => _roundControlCard(drive, brandTheme, theme)).toList(),
              );
            },
            loading: () => const SkeletonCardRow(),
            error: (e, _) => StateBlockWidget(
              icon: Icons.error_outline_rounded,
              title: 'Error loading drives',
              message: e.toString(),
              isError: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundControlCard(Drive drive, AppBrandTheme brandTheme, ThemeData theme) {
    final isDriveClosed = drive.isClosed;
    final statusLower = isDriveClosed ? 'completed' : (drive.isUpcoming ? 'upcoming' : 'active');
    Color statusBg = brandTheme.brassSoft;
    Color statusText = brandTheme.brassPrimary;

    if (statusLower == 'active') {
      statusBg = Colors.greenAccent.withValues(alpha: 0.15);
      statusText = Colors.greenAccent;
    } else if (statusLower == 'completed' || isDriveClosed) {
      statusBg = Colors.blueAccent.withValues(alpha: 0.15);
      statusText = Colors.blueAccent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sp4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandTheme.cardBorder),
        boxShadow: brandTheme.shadow1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Company Name & Status Dropdown Chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drive.companyName.isNotEmpty ? drive.companyName : 'Company',
                      style: GoogleFonts.fraunces(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      drive.roleTitle,
                      style: GoogleFonts.inter(fontSize: 13, color: brandTheme.brassPrimary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusText.withValues(alpha: 0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: statusLower,
                    dropdownColor: theme.colorScheme.surface,
                    icon: Icon(Icons.arrow_drop_down_rounded, color: statusText, size: 20),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: statusText),
                    items: const [
                      DropdownMenuItem(value: 'upcoming', child: Text('UPCOMING')),
                      DropdownMenuItem(value: 'active', child: Text('ACTIVE')),
                      DropdownMenuItem(value: 'completed', child: Text('CLOSED')),
                    ],
                    onChanged: (newStatus) async {
                      if (newStatus == null) return;
                      final repo = ref.read(tpoRepositoryProvider);
                      await repo.updateDriveStatus(driveId: drive.id, status: newStatus);
                      ref.invalidate(tpoDrivesProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Updated ${drive.companyName} status to ${newStatus == 'completed' ? 'CLOSED' : newStatus.toUpperCase()}')),
                        );
                      }
                    },
                  ),
                ),
              ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const SubtleDivider(height: 1),
          const SizedBox(height: 14),

          // Details row
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.payments_outlined, size: 16, color: brandTheme.textMuted),
              Text(
                'CTC: ${drive.ctcOrStipend}',
                style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
              ),
              Icon(Icons.calendar_today_outlined, size: 16, color: brandTheme.textMuted),
              Text(
                'Deadline: ${drive.applicationDeadline.day}/${drive.applicationDeadline.month}/${drive.applicationDeadline.year}',
                style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
              ),
            ],
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/tpo/round-management', extra: drive),
              icon: const Icon(Icons.workspace_premium_rounded, size: 18, color: Colors.black),
              label: Text(
                'Manage Selection Rounds & Offers',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandTheme.brassPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => DriveQrCodeModal(drive: drive),
                );
              },
              icon: Icon(Icons.qr_code_2_rounded, size: 18, color: brandTheme.brassPrimary),
              label: Text(
                'QR Code & Attendance Tracker',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: brandTheme.brassPrimary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: brandTheme.brassPrimary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Action Buttons (Context-Aware)
          if (statusLower == 'completed' || statusLower == 'closed') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 18, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Drive Completed & Closed',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                if (statusLower == 'upcoming')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final repo = ref.read(tpoRepositoryProvider);
                        await repo.updateDriveStatus(driveId: drive.id, status: 'active');
                        ref.invalidate(tpoDrivesProvider);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🚀 Selection rounds initiated! Status: ACTIVE')),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: brandTheme.brassPrimary),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(Icons.play_arrow_rounded, size: 18, color: brandTheme.brassPrimary),
                      label: Text(
                        'Initiate Active Status',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: brandTheme.brassPrimary),
                      ),
                    ),
                  ),
                if (statusLower == 'active' || statusLower == 'ongoing') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final repo = ref.read(tpoRepositoryProvider);
                        await repo.updateDriveStatus(driveId: drive.id, status: 'completed');
                        ref.invalidate(tpoDrivesProvider);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🏁 Recruitment drive completed & closed!')),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: brandTheme.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(Icons.check_circle_outline_rounded, size: 18, color: brandTheme.textMuted),
                      label: Text(
                        'Mark Drive Closed',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: brandTheme.textMuted),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 16),
          const SubtleDivider(height: 1),
          const SizedBox(height: 16),

          // Delete Placement Drive Action (TPO / Admin Only)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDeleteDriveConfirmationDialog(context, drive, brandTheme, theme),
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
              label: Text(
                'Delete Placement Drive',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDriveConfirmationDialog(BuildContext context, Drive drive, AppBrandTheme brandTheme, ThemeData theme) {
    bool isDeleting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: brandTheme.cardBorder),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Delete Placement Drive?',
                      style: GoogleFonts.fraunces(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to delete this placement drive?',
                    style: GoogleFonts.inter(fontSize: 13, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: brandTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: brandTheme.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drive.companyName,
                          style: GoogleFonts.fraunces(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          drive.roleTitle,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This action will remove the drive from Placement Connect and students will no longer be able to view or apply to it.\n\nThis action cannot be undone.',
                    style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted, height: 1.4),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dlgContext),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: brandTheme.textMuted),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          try {
                            final repo = ref.read(tpoRepositoryProvider);
                            await repo.deleteDrive(drive.id);
                            ref.invalidate(tpoDrivesProvider);
                            ref.invalidate(studentEligibleDrivesProvider);

                            if (dlgContext.mounted) {
                              Navigator.pop(dlgContext);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('✓ Placement drive deleted successfully.'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Unable to delete the placement drive. Please try again.'),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.white),
                  label: Text(
                    isDeleting ? 'Deleting...' : 'Delete Drive',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _driveCard(Drive drive, AppBrandTheme brandTheme, ThemeData theme) {
    final companyDisplayName = drive.companyName.isNotEmpty ? drive.companyName : 'Company';
    final statusLower = drive.status.toLowerCase();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: ShapeDecoration(
        color: theme.colorScheme.surface,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
          side: BorderSide(color: brandTheme.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  companyDisplayName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: brandTheme.brassSoft,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  drive.status.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: brandTheme.brassPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            drive.roleTitle,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 2),
          Text(
            'Package: ${drive.ctcOrStipend}',
            style: GoogleFonts.inter(fontSize: 13, color: brandTheme.brassPrimary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          StatusThreadWidget(
            nodes: [
              StatusNodeData(
                label: 'Upcoming',
                isDone: statusLower == 'active' || statusLower == 'ongoing' || statusLower == 'completed' || statusLower == 'closed',
                isCurrent: statusLower == 'upcoming',
              ),
              StatusNodeData(
                label: 'Active',
                isDone: statusLower == 'completed' || statusLower == 'closed',
                isCurrent: statusLower == 'active' || statusLower == 'ongoing',
              ),
              StatusNodeData(
                label: 'Completed',
                isDone: statusLower == 'completed' || statusLower == 'closed',
                isCurrent: statusLower == 'completed' || statusLower == 'closed',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDriveDetailsModal(Drive drive, AppBrandTheme brandTheme, ThemeData theme) {
    final companyDisplayName = drive.companyName.isNotEmpty ? drive.companyName : 'Company';
    final branches = drive.eligibilityBranches.isNotEmpty
        ? drive.eligibilityBranches.join(', ')
        : 'All Eligible Branches';

    final now = DateTime.now();
    String statusReason = '';
    final statusLower = drive.status.toLowerCase();
    if (statusLower == 'upcoming') {
      statusReason = 'Status is UPCOMING because registration is currently open for eligible students before selection rounds begin.';
    } else if (statusLower == 'active' || statusLower == 'ongoing') {
      statusReason = 'Status is ACTIVE/ONGOING because drive rounds (assessments & interviews) are actively in progress.';
    } else if (statusLower == 'completed' || statusLower == 'closed') {
      statusReason = 'Status is COMPLETED/CLOSED because the application deadline has passed or all offer letters have been issued.';
    } else {
      if (now.isBefore(drive.applicationDeadline)) {
        statusReason = 'Status is based on active registration period ending on ${drive.applicationDeadline.day}/${drive.applicationDeadline.month}/${drive.applicationDeadline.year}.';
      } else {
        statusReason = 'Status is based on recruitment process lifecycle set in Supabase database ($statusLower).';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).padding.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: brandTheme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      companyDisplayName,
                      style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: brandTheme.brassSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      drive.status.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: brandTheme.brassPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                drive.roleTitle,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary),
              ),
              const SizedBox(height: 16),
              const SubtleDivider(),
              const SizedBox(height: 12),
              
              // Status Basis Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: brandTheme.brassSoft.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: brandTheme.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20, color: brandTheme.brassPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Basis (${drive.status.toUpperCase()})',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: brandTheme.brassPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusReason,
                            style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Text('Drive Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),

              _detailRow(Icons.monetization_on_outlined, 'Package / CTC', drive.ctcOrStipend, brandTheme),
              _detailRow(Icons.school_outlined, 'Eligible Branches', branches, brandTheme),
              _detailRow(Icons.grade_outlined, 'Min. CGPA Cutoff', '${drive.cgpaCutoff}', brandTheme),
              _detailRow(Icons.history_edu_outlined, 'Max Allowed Backlogs', '${drive.backlogLimit}', brandTheme),
              _detailRow(Icons.event_outlined, 'Application Deadline', '${drive.applicationDeadline.day}/${drive.applicationDeadline.month}/${drive.applicationDeadline.year}', brandTheme),

              if (drive.jobDescription.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Job Description', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  drive.jobDescription,
                  style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, AppBrandTheme brandTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: brandTheme.textMuted),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showApplicantsSheet(Drive drive, AppBrandTheme brandTheme, ThemeData theme) {
    ref.invalidate(tpoDriveApplicantsProvider(drive.id));
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final applicantsAsync = ref.watch(tpoDriveApplicantsProvider(drive.id));
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.75,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                expand: false,
                builder: (ctx, scrollController) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: brandTheme.textMuted.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Applicants',
                                  style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${drive.companyName} — ${drive.roleTitle}',
                                  style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: Icon(Icons.close_rounded, color: brandTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // ── Search Input Bar ─────────────────────────────────
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: brandTheme.cardBorder),
                        ),
                        child: TextField(
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val;
                            });
                          },
                          style: GoogleFonts.inter(fontSize: 13, color: theme.colorScheme.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Search applicants by name, USN, department...',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: brandTheme.textMuted),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close_rounded, size: 16, color: brandTheme.textMuted),
                                    onPressed: () {
                                      setModalState(() {
                                        searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: applicantsAsync.when(
                          data: (applicants) {
                            if (applicants.isEmpty) {
                              return RefreshIndicator(
                                onRefresh: () async {
                                  ref.invalidate(tpoDriveApplicantsProvider(drive.id));
                                  await ref.read(tpoDriveApplicantsProvider(drive.id).future);
                                },
                                child: ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.people_outline_rounded, size: 40, color: brandTheme.textMuted),
                                          const SizedBox(height: 12),
                                          Text('No applications yet', style: GoogleFonts.inter(fontSize: 14, color: brandTheme.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final query = searchQuery.trim().toLowerCase();
                            final filtered = applicants.where((app) {
                              if (query.isEmpty) return true;
                              final student = app['student'] as Map<String, dynamic>? ?? {};
                              final name = (student['name'] as String? ?? '').toLowerCase();
                              final usn = (student['usn'] as String? ?? '').toLowerCase();
                              final dept = (student['department'] as String? ?? '').toLowerCase();
                              final status = (app['status'] as String? ?? '').toLowerCase();
                              return name.contains(query) || usn.contains(query) || dept.contains(query) || status.contains(query);
                            }).toList();

                            if (filtered.isEmpty) {
                              return RefreshIndicator(
                                onRefresh: () async {
                                  ref.invalidate(tpoDriveApplicantsProvider(drive.id));
                                  await ref.read(tpoDriveApplicantsProvider(drive.id).future);
                                },
                                child: ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                                    Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.search_off_rounded, size: 36, color: brandTheme.textMuted),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No matching applicants found',
                                            style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return RefreshIndicator(
                              onRefresh: () async {
                                ref.invalidate(tpoDriveApplicantsProvider(drive.id));
                                await ref.read(tpoDriveApplicantsProvider(drive.id).future);
                              },
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                controller: scrollController,
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                final app = filtered[i];
                                final student = app['student'] as Map<String, dynamic>? ?? {};
                                final name = student['name'] as String? ?? 'Student';
                                final usn = student['usn'] as String? ?? '';
                                final dept = student['department'] as String? ?? '';
                                final cgpa = student['cgpa'];
                                final status = app['status'] as String? ?? 'applied';
                                final appliedAt = app['applied_at'] as String?;
                                final dateStr = appliedAt != null
                                    ? DateTime.tryParse(appliedAt)?.toIso8601String().split('T').first ?? ''
                                    : '';

                                Color statusBg;
                                Color statusText;
                                switch (status) {
                                  case 'shortlisted':
                                    statusBg = Colors.greenAccent.withValues(alpha: 0.15);
                                    statusText = Colors.greenAccent;
                                    break;
                                  case 'rejected':
                                    statusBg = Colors.redAccent.withValues(alpha: 0.15);
                                    statusText = Colors.redAccent;
                                    break;
                                  case 'selected':
                                    statusBg = Colors.amberAccent.withValues(alpha: 0.15);
                                    statusText = Colors.amberAccent;
                                    break;
                                  default:
                                    statusBg = brandTheme.brassSoft;
                                    statusText = brandTheme.brassPrimary;
                                }

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      context.push('/tpo/student-progress', extra: {
                                        'drive': drive,
                                        'applicationId': app['id'] as String,
                                        'studentName': name,
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: brandTheme.cardBorder),
                                      ),
                                      child: Row(
                                        children: [
                                          ProfileAvatar(
                                            imageUrl: (student['photo_url'] ?? student['avatar_url']) as String?,
                                            name: name,
                                            size: ProfileAvatarSize.small,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  [if (usn.isNotEmpty) usn, if (dept.isNotEmpty) dept].join(' · '),
                                                  style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
                                                ),
                                                if (cgpa != null) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'CGPA: ${cgpa is num ? cgpa.toStringAsFixed(2) : cgpa}',
                                                    style: GoogleFonts.ibmPlexMono(fontSize: 11, color: brandTheme.brassPrimary),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: statusBg,
                                                    borderRadius: BorderRadius.circular(100),
                                                  ),
                                                  child: Text(
                                                    status.toUpperCase(),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusText),
                                                  ),
                                                ),
                                                if (dateStr.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(dateStr, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.ibmPlexMono(fontSize: 10, color: brandTheme.textMuted)),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(
                            child: Text('Error loading applicants: $e', style: GoogleFonts.inter(fontSize: 13)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}



