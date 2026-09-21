import '../../../../core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/faculty_provider.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/floating_pill_nav_bar.dart';
import '../../../../shared/presentation/widgets/skeleton_loader.dart';
import '../../../../shared/presentation/widgets/state_block_widget.dart';
import '../../../../shared/presentation/widgets/status_thread_widget.dart';
import '../../../../shared/presentation/widgets/subtle_divider.dart';
import '../../../../shared/presentation/widgets/app_logo.dart';
import '../../../../shared/presentation/widgets/app_refresh_indicator.dart';
import '../../../student/domain/entities/drive.dart';
import '../../../tpo/presentation/providers/tpo_provider.dart';
import 'student_approval_queue_screen.dart';
import 'department_analytics_screen.dart';

class FacultyDashboardScreen extends ConsumerStatefulWidget {
  const FacultyDashboardScreen({super.key});

  @override
  ConsumerState<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends ConsumerState<FacultyDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final currentNavIndex = ref.watch(facultyDashboardTabProvider);
    final profileAsync = ref.watch(authNotifierProvider);
    final pendingStudentsAsync = ref.watch(pendingStudentsProvider);
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    final pendingCount = pendingStudentsAsync.valueOrNull?.length ?? 0;

    final navDestinations = [
      const NavDestinationItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        label: 'Overview',
      ),
      NavDestinationItem(
        icon: Icons.verified_user_outlined,
        selectedIcon: Icons.verified_user_rounded,
        label: 'Verify',
        hasBadge: pendingCount > 0,
        badgeCount: pendingCount,
      ),
      const NavDestinationItem(
        icon: Icons.analytics_outlined,
        selectedIcon: Icons.analytics_rounded,
        label: 'Analytics',
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
          ref.read(facultyDashboardTabProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: profileAsync.when(
              data: (profile) => _buildTabContent(currentNavIndex, profile?.fullName ?? 'Faculty Advisor', brandTheme, theme),
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 80, left: 16, right: 16),
                child: Column(
                  children: [
                    SkeletonCardRow(),
                    SkeletonCardRow(),
                  ],
                ),
              ),
              error: (e, _) => StateBlockWidget(
                icon: Icons.error_outline_rounded,
                title: "Couldn't load dashboard",
                message: e.toString(),
                isError: true,
              ),
            ),
          ),

          // Floating Pill Nav Bar
          FloatingPillNavBar(
            selectedIndex: currentNavIndex,
            onDestinationSelected: (index) => ref.read(facultyDashboardTabProvider.notifier).state = index,
            items: navDestinations,
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildTabContent(int tabIndex, String facultyName, AppBrandTheme brandTheme, ThemeData theme) {
    switch (tabIndex) {
      case 0:
        return _overviewTab(facultyName, brandTheme, theme);
      case 1:
        return _verificationTab(facultyName, theme, brandTheme);
      case 2:
        return _analyticsTab(theme, brandTheme);
      case 3:
        return _profileTab(facultyName, theme, brandTheme);
      default:
        return _overviewTab(facultyName, brandTheme, theme);
    }
  }

  Widget _overviewTab(String name, AppBrandTheme brandTheme, ThemeData theme) {
    final pendingStudentsAsync = ref.watch(pendingStudentsProvider);
    final topPadding = MediaQuery.of(context).padding.top + AppSpacing.sp3;

    return AppRefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.refresh(pendingStudentsProvider.future),
          ref.refresh(verifiedStudentsProvider.future),
          ref.refresh(tpoDrivesProvider.future),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: topPadding,
          left: AppSpacing.sp5,
          right: AppSpacing.sp5,
          bottom: 110,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppLogo(size: 42, showGlow: true),
              const SizedBox(width: AppSpacing.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
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
                      'Department Faculty Advisor',
                      style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.logout_rounded, size: 20, color: brandTheme.textMuted),
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sp5),

          pendingStudentsAsync.when(
            data: (students) {
              final pendingCount = students.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bento Primary Tile (B1 - 1.3fr)
                      Expanded(
                        flex: 13,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const StudentApprovalQueueScreen()),
                            );
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 160),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$pendingCount',
                                      style: GoogleFonts.fraunces(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w600,
                                        color: brandTheme.brassPrimary,
                                        height: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pending Verifications →',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: brandTheme.brassPrimary,
                                      ),
                                    ),
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
                        child: SizedBox(
                          height: 160,
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSpacing.sp3),
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
                                      ref.watch(verifiedStudentsProvider).when(
                                            data: (verified) => Text(
                                              '${verified.length}',
                                              style: GoogleFonts.fraunces(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w600,
                                                color: brandTheme.statusShortlisted,
                                              ),
                                            ),
                                            loading: () => const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            error: (_, __) => Text('0',
                                                style: GoogleFonts.fraunces(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w600,
                                                    color: brandTheme.statusShortlisted)),
                                          ),
                                      Text(
                                        'Verified Students',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: brandTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sp2),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSpacing.sp3),
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
                                      ref.watch(deptPlacementStatsProvider).when(
                                            data: (stats) => Text(
                                              '${stats['total_students'] ?? 0}',
                                              style: GoogleFonts.fraunces(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            loading: () => const SizedBox(
                                              height: 16,
                                              width: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                            error: (_, __) => Text('0',
                                                style: GoogleFonts.fraunces(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.colorScheme.onSurface)),
                                          ),
                                      Text(
                                        'Total Batch',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: brandTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sp6),

                  Text(
                    'PLACEMENT DRIVES OVERVIEW',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.08,
                      color: brandTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sp3),

                  ref.watch(tpoDrivesProvider).when(
                    loading: () => const SkeletonCardRow(),
                    error: (e, _) => StateBlockWidget(
                      icon: Icons.error_outline_rounded,
                      title: 'Failed to load placement drives',
                      message: e.toString(),
                      isError: true,
                    ),
                    data: (drives) {
                      if (drives.isEmpty) {
                        return const StateBlockWidget(
                          icon: Icons.work_off_outlined,
                          title: 'No Placement Drives',
                          message: 'There are currently no active or upcoming placement drives.',
                        );
                      }
                      return Column(
                        children: drives.map((drive) => _facultyDriveOverviewCard(drive, theme, brandTheme)).toList(),
                      );
                    },
                  ),
                ],
              );
            },
            loading: () => const SkeletonCardRow(),
            error: (e, _) => StateBlockWidget(
              icon: Icons.error_outline_rounded,
              title: 'Failed to load requests',
              message: e.toString(),
              isError: true,
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _verificationTab(String facultyName, ThemeData theme, AppBrandTheme brandTheme) {
    return const StudentApprovalQueueScreen();
  }

  Widget _analyticsTab(ThemeData theme, AppBrandTheme brandTheme) {
    final profileAsync = ref.watch(authNotifierProvider);
    return profileAsync.when(
      data: (profile) {
        final dept = profile?.department ?? '';
        if (dept.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.apartment_rounded, size: 48, color: brandTheme.textMuted),
                const SizedBox(height: 12),
                Text('No department assigned',
                    style: GoogleFonts.inter(fontSize: 16, color: brandTheme.textMuted)),
              ],
            ),
          );
        }
        return _DepartmentAnalyticsStub(department: dept);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _profileTab(String name, ThemeData theme, AppBrandTheme brandTheme) {
    final user = ref.watch(authNotifierProvider).value;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.sp4,
        left: AppSpacing.sp5,
        right: AppSpacing.sp5,
        bottom: 110,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Container(
            width: double.infinity,
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
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: brandTheme.brassGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: brandTheme.brassPrimary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'F',
                      style: GoogleFonts.fraunces(fontSize: 36, color: brandTheme.onBrass, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sp4),
                Text(name, style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandTheme.brassPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: brandTheme.brassPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'FACULTY COORDINATOR (FC)',
                    style: GoogleFonts.ibmPlexMono(fontSize: 10, fontWeight: FontWeight.bold, color: brandTheme.brassPrimary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sp5),
          Text('Faculty Information', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sp3),

          // Details List Container
          Container(
            decoration: ShapeDecoration(
              color: theme.colorScheme.surface,
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                side: BorderSide(color: brandTheme.cardBorder),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.sp4),
            child: Column(
              children: [
                _profileInfoTile(Icons.person_outline_rounded, 'Full Name', name, brandTheme),
                const SubtleDivider(height: 20),
                _profileInfoTile(Icons.apartment_rounded, 'Department', user?.department ?? 'Information Science & Engineering', brandTheme),
                const SubtleDivider(height: 20),
                _profileInfoTile(Icons.email_outlined, 'Email Address', user?.email ?? 'faculty@mcehassan.ac.in', brandTheme),
                if (user?.phone != null && user!.phone!.isNotEmpty) ...[
                  const SubtleDivider(height: 20),
                  _profileInfoTile(Icons.phone_outlined, 'Contact Phone', user.phone!, brandTheme),
                ],
                const SubtleDivider(height: 20),
                _profileInfoTile(Icons.verified_user_outlined, 'Account Role', 'Faculty Coordinator (FC)', brandTheme),
                const SubtleDivider(height: 20),
                _profileInfoTile(Icons.security_rounded, 'Verification Status', 'Verified Administrator ✓', brandTheme, isAccent: true),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.sp5),

          // Sign Out Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
              icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
              label: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileInfoTile(IconData icon, String label, String value, AppBrandTheme brandTheme, {bool isAccent = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isAccent ? brandTheme.brassPrimary : brandTheme.textMuted).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: isAccent ? brandTheme.brassPrimary : brandTheme.textMuted),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted)),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isAccent ? brandTheme.brassPrimary : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _facultyDriveOverviewCard(Drive drive, ThemeData theme, AppBrandTheme brandTheme) {
    final statusLower = drive.status.toLowerCase();
    final companyDisplayName = drive.companyName.isNotEmpty ? drive.companyName : 'Company';

    return InkWell(
      onTap: () => _showDriveDetailsModal(drive, theme, brandTheme),
      borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
      child: Container(
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
                Expanded(
                  child: Text(
                    companyDisplayName,
                    style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
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
            const SizedBox(height: 4),
            Text(
              drive.roleTitle,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              'Package: ${drive.ctcOrStipend}',
              style: GoogleFonts.inter(fontSize: 12, color: brandTheme.brassPrimary, fontWeight: FontWeight.w500),
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
      ),
    );
  }

  void _showDriveDetailsModal(Drive drive, ThemeData theme, AppBrandTheme brandTheme) {
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
                    color: brandTheme.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: brandTheme.brassSoft,
                    child: Icon(Icons.business_rounded, color: brandTheme.brassPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drive.companyName,
                          style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          drive.roleTitle,
                          style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandTheme.brassSoft,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      drive.status.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: brandTheme.brassPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SubtleDivider(),
              const SizedBox(height: 12),
              Text('Drive Specification & Details', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),

              _driveDetailRow(Icons.monetization_on_outlined, 'Package / CTC', drive.ctcOrStipend, brandTheme),
              _driveDetailRow(Icons.apartment_rounded, 'Target Branches', drive.targetBranches.join(', '), brandTheme),
              _driveDetailRow(Icons.grade_outlined, 'Min CGPA Requirement', '${drive.minCgpa}', brandTheme),
              _driveDetailRow(Icons.history_edu_outlined, 'Max Active Backlogs', '${drive.maxBacklogs}', brandTheme),

              _driveDetailRow(
                Icons.event_outlined,
                'Application Deadline',
                '${drive.deadline.day}/${drive.deadline.month}/${drive.deadline.year}',
                brandTheme,
              ),

              if (drive.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Role Description', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: brandTheme.cardBorder),
                  ),
                  child: Text(
                    drive.description,
                    style: GoogleFonts.inter(fontSize: 12, height: 1.4, color: brandTheme.textMuted),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _driveDetailRow(IconData icon, String label, String value, AppBrandTheme brandTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: brandTheme.textMuted),
          const SizedBox(width: 10),
          Text('$label: ', style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Embeds the DepartmentAnalyticsScreen inside the tab without its own Scaffold/AppBar.
class _DepartmentAnalyticsStub extends StatelessWidget {
  final String department;
  const _DepartmentAnalyticsStub({required this.department});

  @override
  Widget build(BuildContext context) {
    return DepartmentAnalyticsScreen(department: department);
  }
}


