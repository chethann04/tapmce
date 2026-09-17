import '../../../../core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/tpo_provider.dart';
import '../../../student/domain/entities/drive.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/floating_pill_nav_bar.dart';
import '../../../../shared/presentation/widgets/skeleton_loader.dart';
import '../../../../shared/presentation/widgets/state_block_widget.dart';
import '../../../../shared/presentation/widgets/status_thread_widget.dart';
import '../../../../shared/presentation/widgets/subtle_divider.dart';
import '../../../../shared/presentation/widgets/app_logo.dart';
import '../../../../shared/presentation/widgets/app_refresh_indicator.dart';
import '../widgets/drive_qr_code_modal.dart';
import 'drive_creation_wizard.dart';

class TpoDashboardScreen extends ConsumerStatefulWidget {
  const TpoDashboardScreen({super.key});

  @override
  ConsumerState<TpoDashboardScreen> createState() => _TpoDashboardScreenState();
}

class _TpoDashboardScreenState extends ConsumerState<TpoDashboardScreen> {
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
                data: (profile) => _buildTabContent(currentNavIndex, profile?.fullName ?? 'TPO Officer', brandTheme, theme),
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
                child: GestureDetector(
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
                child: GestureDetector(
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
                      '2026-27 Academic Cycle · Placement Cell',
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

          drivesAsync.when(
            data: (drives) {
              final activeDrivesCount = drives.length;
              final applicantsCount = applicantsAsync.valueOrNull ?? 0;
              final offersCount = offersAsync.valueOrNull ?? 0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bento Primary Tile (B1 - 1.3fr)
                  Expanded(
                    flex: 13,
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
                                '$activeDrivesCount',
                                style: GoogleFonts.fraunces(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  color: brandTheme.brassPrimary,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Active Drives',
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
                                  Text(
                                    '$applicantsCount',
                                    style: GoogleFonts.fraunces(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Applicants',
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
                                  Text(
                                    '$offersCount',
                                    style: GoogleFonts.fraunces(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      color: brandTheme.statusShortlisted,
                                    ),
                                  ),
                                  Text(
                                    'Offers',
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
              );
            },
            loading: () => const SkeletonCardRow(),
            error: (err, _) => StateBlockWidget(
              icon: Icons.error_outline_rounded,
              title: "Notice",
              message: "Unable to refresh active statistics: ${err.toString()}",
            ),
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
                  final statusLower = drive.status.toLowerCase();
                  Color statusBg = brandTheme.brassSoft;
                  Color statusText = brandTheme.brassPrimary;
                  if (statusLower == 'active' || statusLower == 'ongoing') {
                    statusBg = Colors.greenAccent.withValues(alpha: 0.15);
                    statusText = Colors.greenAccent;
                  } else if (statusLower == 'completed' || statusLower == 'closed') {
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
                                      drive.status.toUpperCase(),
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
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: brandTheme.brassSoft,
                              child: Icon(Icons.person_rounded, color: brandTheme.brassPrimary, size: 22),
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
    final statusLower = drive.status.toLowerCase();
    Color statusBg = brandTheme.brassSoft;
    Color statusText = brandTheme.brassPrimary;

    if (statusLower == 'active' || statusLower == 'ongoing') {
      statusBg = Colors.greenAccent.withValues(alpha: 0.15);
      statusText = Colors.greenAccent;
    } else if (statusLower == 'completed' || statusLower == 'closed') {
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
                    value: ['upcoming', 'active', 'completed', 'ongoing', 'closed'].contains(statusLower)
                        ? (statusLower == 'ongoing' ? 'active' : (statusLower == 'closed' ? 'completed' : statusLower))
                        : 'upcoming',
                    dropdownColor: theme.colorScheme.surface,
                    icon: Icon(Icons.arrow_drop_down_rounded, color: statusText, size: 20),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 11, color: statusText),
                    items: const [
                      DropdownMenuItem(value: 'upcoming', child: Text('UPCOMING')),
                      DropdownMenuItem(value: 'active', child: Text('ACTIVE')),
                      DropdownMenuItem(value: 'completed', child: Text('COMPLETED')),
                    ],
                    onChanged: (newStatus) async {
                      if (newStatus == null) return;
                      final repo = ref.read(tpoRepositoryProvider);
                      await repo.updateDriveStatus(driveId: drive.id, status: newStatus);
                      ref.invalidate(tpoDrivesProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Updated ${drive.companyName} status to ${newStatus.toUpperCase()}')),
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

          const SizedBox(height: 16),

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
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
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
          ] else ...[
            Row(
              children: [
                if (statusLower == 'upcoming')
                  Expanded(
                    child: ElevatedButton.icon(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandTheme.brassPrimary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.black),
                      label: Text(
                        'Start Rounds',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                      ),
                    ),
                  ),
                if (statusLower == 'active' || statusLower == 'ongoing') ...[
                  Expanded(
                    child: ElevatedButton.icon(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandTheme.brassPrimary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.black),
                      label: Text(
                        'Finish Drive',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
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
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people_outline_rounded, size: 40, color: brandTheme.textMuted),
                                    const SizedBox(height: 12),
                                    Text('No applications yet', style: GoogleFonts.inter(fontSize: 14, color: brandTheme.textMuted)),
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
                              return Center(
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
                              );
                            }

                            return ListView.separated(
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
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: brandTheme.brassSoft,
                                            child: Text(
                                              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                                              style: GoogleFonts.fraunces(fontSize: 14, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary),
                                            ),
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



