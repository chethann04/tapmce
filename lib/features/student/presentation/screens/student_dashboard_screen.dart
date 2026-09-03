import '../../../../core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/file_name_extractor.dart';
import '../../../../shared/presentation/widgets/floating_pill_nav_bar.dart';
import '../../../../shared/presentation/widgets/skeleton_loader.dart';
import '../../../../shared/presentation/widgets/state_block_widget.dart';
import '../../../../shared/presentation/widgets/app_logo.dart';
import '../providers/student_drive_provider.dart';
import '../../domain/entities/application.dart';
import '../../domain/entities/drive.dart';
import 'student_application_timeline_screen.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {


  static const _navDestinations = [
    NavDestinationItem(icon: Icons.home_rounded, label: 'Home'),
    NavDestinationItem(icon: Icons.work_rounded, label: 'Drives'),
    NavDestinationItem(icon: Icons.timeline_rounded, label: 'Timeline'),
    NavDestinationItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentNavIndex = ref.watch(studentDashboardTabProvider);
    final profileAsync = ref.watch(authNotifierProvider);
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    final profile = profileAsync.valueOrNull;

    return PopScope(
      canPop: currentNavIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentNavIndex != 0) {
          ref.read(studentDashboardTabProvider.notifier).state = 0;
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Content layer with bottom padding for floating bar
            Positioned.fill(
              child: _buildTabContent(currentNavIndex, profile, brandTheme, theme),
            ),

            // Floating Pill Nav Bar
            FloatingPillNavBar(
              selectedIndex: currentNavIndex,
              onDestinationSelected: (index) => ref.read(studentDashboardTabProvider.notifier).state = index,
              items: _navDestinations,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex, dynamic profile, AppBrandTheme brandTheme, ThemeData theme) {
    final name = profile?.fullName ?? 'Student';

    switch (tabIndex) {
      case 0:
        return _dashboardTab(context, profile, name, brandTheme, theme);
      case 1:
        return _drivesTab(theme, brandTheme);
      case 2:
        return _applicationsTab(theme, brandTheme);
      case 3:
        return _profileTab(profile, brandTheme, theme);
      default:
        return _dashboardTab(context, profile, name, brandTheme, theme);
    }
  }

  Widget _dashboardTab(BuildContext context, UserProfile? profile, String name, AppBrandTheme brandTheme, ThemeData theme) {
    final appsAsync = ref.watch(studentApplicationsProvider);
    final drivesAsync = ref.watch(studentEligibleDrivesProvider);
    final appliedIds = ref.watch(studentAppliedDriveIdsProvider);
    final topPadding = MediaQuery.of(context).padding.top + AppSpacing.sp3;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: topPadding,
        left: AppSpacing.sp5,
        right: AppSpacing.sp5,
        bottom: 110,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & User Header
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
                        text: 'Hey, ',
                        style: GoogleFonts.fraunces(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text: name.split(' ').first,
                            style: GoogleFonts.fraunces(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: brandTheme.brassPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile != null
                          ? [
                              if (profile.graduationYear != null) 'Batch ${profile.graduationYear}',
                              if (profile.department != null && profile.department!.isNotEmpty) profile.department,
                            ].where((s) => s != null && s.isNotEmpty).join(' · ')
                          : '',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: brandTheme.textMuted,
                      ),
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

          Builder(
            builder: (context) {
              final apps = appsAsync.valueOrNull ?? const <Application>[];
              final shortlistedCount = apps.where((a) => a.status == ApplicationStatus.shortlisted).length;
              final offersCount = apps.where((a) => a.status == ApplicationStatus.selected).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 13,
                        child: Container(
                          height: 140,
                          padding: const EdgeInsets.all(AppSpacing.sp4),
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
                              Text(
                                '${apps.length}',
                                style: GoogleFonts.fraunces(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w600,
                                  color: brandTheme.brassPrimary,
                                  height: 1.0,
                                ),
                              ),
                              Text(
                                'Active applications',
                                style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sp3),
                      Expanded(
                        flex: 10,
                        child: SizedBox(
                          height: 140,
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp3, vertical: AppSpacing.sp2),
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
                                      Text('$shortlistedCount', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
                                      Text('Shortlisted', style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sp2),
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp3, vertical: AppSpacing.sp2),
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
                                      Text('$offersCount', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: brandTheme.statusShortlisted)),
                                      Text('Offers', style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted)),
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

                  // ── Scan Attendance ───────────────────────────────────
                  GestureDetector(
                    onTap: () => context.push('/student/scan-attendance'),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sp4),
                      decoration: BoxDecoration(
                        gradient: brandTheme.brassGradient,
                        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                        boxShadow: brandTheme.shadow2,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: AppSpacing.sp3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scan Attendance', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                                const SizedBox(height: 2),
                                Text('Scan QR code at the drive venue', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.7), size: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sp6),

                  // ── Open Drives ────────────────────────────────────────
                  Text(
                    'OPEN DRIVES FOR YOU',
                    style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.08, color: brandTheme.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sp3),
                  drivesAsync.when(
                    data: (drives) {
                      if (drives.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sp4),
                          decoration: ShapeDecoration(
                            color: theme.colorScheme.surface,
                            shape: ContinuousRectangleBorder(
                              borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                              side: BorderSide(color: brandTheme.cardBorder),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.work_off_outlined, size: 28, color: brandTheme.textMuted),
                              const SizedBox(height: AppSpacing.sp2),
                              Text('No eligible drives right now', style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
                            ],
                          ),
                        );
                      }
                      return SizedBox(
                        height: _carouselHeight(drives),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: drives.length,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sp3),
                          itemBuilder: (_, i) {
                            final d = drives[i];
                            final isApplied = appliedIds.contains(d.id);
                            return _horizontalDriveCard(d, isApplied, brandTheme, theme);
                          },
                        ),
                      );
                    },
                    loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
                    error: (_, __) => const SizedBox(),
                  ),
                  const SizedBox(height: AppSpacing.sp6),

                  // ── Recent Activity ────────────────────────────────────
                  Text(
                    'RECENT ACTIVITY',
                    style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.08, color: brandTheme.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sp3),
                  _buildRecentActivity(apps, brandTheme, theme),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List<Application> apps, AppBrandTheme brandTheme, ThemeData theme) {
    if (apps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sp4),
        decoration: ShapeDecoration(
          color: theme.colorScheme.surface,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
            side: BorderSide(color: brandTheme.cardBorder),
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.notifications_none_rounded, size: 28, color: brandTheme.textMuted),
            const SizedBox(height: AppSpacing.sp2),
            Text('No recent activity', style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
          ],
        ),
      );
    }

    // Take latest 5, sorted by appliedAt descending
    final recent = List<Application>.from(apps)
      ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));
    final items = recent.take(5).toList();

    return Column(
      children: items.map((app) {
        final companyName = app.companyName;
        final roleName = app.roleName;

        IconData icon;
        Color iconColor;
        String actionText;

        switch (app.status) {
          case ApplicationStatus.shortlisted:
            icon = Icons.check_circle_rounded;
            iconColor = brandTheme.statusShortlisted;
            actionText = 'Shortlisted by $companyName';
            break;
          case ApplicationStatus.interview:
            icon = Icons.mic_rounded;
            iconColor = brandTheme.statusPending;
            actionText = 'Interview at $companyName';
            break;
          case ApplicationStatus.selected:
            icon = Icons.celebration_rounded;
            iconColor = brandTheme.statusShortlisted;
            actionText = 'Offer from $companyName';
            break;
          case ApplicationStatus.rejected:
            icon = Icons.cancel_rounded;
            iconColor = brandTheme.statusRejected;
            actionText = 'Not selected by $companyName';
            break;
          default:
            icon = Icons.send_rounded;
            iconColor = brandTheme.brassPrimary;
            actionText = 'Applied to $companyName';
        }

        final timeAgo = _formatTimeAgo(app.appliedAt);

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sp2),
          padding: const EdgeInsets.all(AppSpacing.sp4),
          decoration: ShapeDecoration(
            color: theme.colorScheme.surface,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
              side: BorderSide(color: brandTheme.cardBorder),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.16),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(actionText, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(roleName, style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
                  ],
                ),
              ),
              Text(timeAgo, style: GoogleFonts.ibmPlexMono(fontSize: 10, color: brandTheme.textMuted)),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 7) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  /// Estimates how tall the horizontal drive carousel must be so that the
  /// tallest card (longest company / role / package text, worst-case wrapping)
  /// always fits without clipping or fixed-height overflow.
  double _carouselHeight(List<Drive> drives) {
    const cardWidth = 220.0;
    final textWidth = cardWidth - AppSpacing.sp4 * 2;
    var maxHeight = 185.0;
    for (final d in drives) {
      final companyLines = _estimateTextLines(d.companyName, 16, textWidth);
      final roleLines = _estimateTextLines('${d.roleTitle} · ', 12, textWidth);
      final estimated = 185.0 +
          (companyLines - 1) * 19.0 +
          (roleLines - 1) * 15.0;
      if (estimated > maxHeight) maxHeight = estimated;
    }
    return maxHeight;
  }

  int _estimateTextLines(String text, double fontSize, double width) {
    if (text.isEmpty) return 1;
    // Average glyph width is ~0.55x the font size for inter/sans fonts.
    final charsPerLine =
        (width / (fontSize * 0.55)).floor().clamp(1, 5000).toInt();
    return (text.length / charsPerLine).ceil().clamp(1, 200).toInt();
  }

  Widget _horizontalDriveCard(Drive drive, bool isApplied, AppBrandTheme brandTheme, ThemeData theme) {
    final daysLeft = drive.applicationDeadline.difference(DateTime.now()).inDays;
    final deadlineText = daysLeft > 0 ? 'Closes in ${daysLeft}d' : 'Closing today';
    final badge = drive.cgpaCutoff > 0 ? 'CGPA ${drive.cgpaCutoff}+' : 'All branches';

    return GestureDetector(
      onTap: () {
        if (isApplied) {
          // Navigate to Timeline tab (index 2)
          ref.read(studentDashboardTabProvider.notifier).state = 2;
        } else {
          context.push('/student/drive-details', extra: drive);
        }
      },
      child: Container(
        width: 220,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: brandTheme.brassGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      drive.companyName.substring(0, drive.companyName.length.clamp(0, 2)).toUpperCase(),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: brandTheme.onBrass),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    drive.companyName,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${drive.roleTitle} · $deadlineText',
                    style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            isApplied
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandTheme.statusShortlisted.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 12, color: brandTheme.statusShortlisted),
                        const SizedBox(width: 4),
                        Text('Applied', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: brandTheme.statusShortlisted)),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandTheme.brassSoft,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: brandTheme.brassPrimary)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _drivesTab(ThemeData theme, AppBrandTheme brandTheme) {
    final drivesAsync = ref.watch(studentEligibleDrivesProvider);
    final appliedIds = ref.watch(studentAppliedDriveIdsProvider);

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
          Text('Campus Placement Drives', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Drives open for your batch & eligibility', style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
          const SizedBox(height: AppSpacing.sp5),
          drivesAsync.when(
            data: (drives) {
              if (drives.isEmpty) {
                return StateBlockWidget(
                  icon: Icons.work_off_outlined,
                  title: 'No drives open right now',
                  message: "Check back after your coordinator publishes this cycle's calendar — you'll get a notification the moment a new drive opens.",
                );
              }
              return Column(
                children: drives.map((d) => _driveItem(d, appliedIds.contains(d.id), theme, brandTheme)).toList(),
              );
            },
            loading: () => Column(
              children: const [
                SkeletonCardRow(),
                SkeletonCardRow(),
              ],
            ),
            error: (e, _) => StateBlockWidget(
              icon: Icons.error_outline_rounded,
              title: "Couldn't load drives",
              message: e.toString(),
              isError: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _applicationsTab(ThemeData theme, AppBrandTheme brandTheme) {
    return const StudentApplicationTimelineScreen();
  }

  Widget _profileTab(UserProfile? profile, AppBrandTheme brandTheme, ThemeData theme) {
    final name = profile?.name ?? 'Student';
    final usn = profile?.usn ?? '';
    final dept = profile?.department ?? '';
    final semester = profile?.semester;
    final section = profile?.section;
    final cgpa = profile?.cgpa;
    final approvalStatus = profile?.approvalStatus;

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
          // ── Profile Header ────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                // Photo or Initial
                if (profile?.photoUrl != null && profile!.photoUrl!.isNotEmpty)
                  ClipOval(
                    child: Image.network(
                      profile.photoUrl!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(name, brandTheme),
                    ),
                  )
                else
                  _avatarFallback(name, brandTheme),
                const SizedBox(height: AppSpacing.sp3),
                Text(name, style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600)),
                if (usn.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(usn, style: GoogleFonts.ibmPlexMono(fontSize: 13, color: brandTheme.textMuted)),
                ],
                if (dept.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(dept, style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
                ],
                if (semester != null || section != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (semester != null) 'Semester $semester',
                      if (section != null) 'Section $section',
                    ].join(' • '),
                    style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
                  ),
                ],
                if (cgpa != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'CGPA ${cgpa.toStringAsFixed(2)}',
                    style: GoogleFonts.ibmPlexMono(fontSize: 13, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary),
                  ),
                ],
                const SizedBox(height: AppSpacing.sp3),
                // Verification badge
                _verificationBadge(approvalStatus, brandTheme),
                const SizedBox(height: AppSpacing.sp4),
                // Edit Profile button
                GestureDetector(
                  onTap: () => context.push('/student/profile-edit', extra: 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: brandTheme.brassGradient,
                      borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                    ),
                    child: Text('Edit Profile Details', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: brandTheme.onBrass)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sp6),

          // ── Quick Stats ───────────────────────────────────────────────
          _sectionHeader('Quick Stats', brandTheme),
          const SizedBox(height: AppSpacing.sp2),
          Row(
            children: [
              Expanded(child: _statCard('CGPA', cgpa != null ? cgpa.toStringAsFixed(2) : '—', brandTheme, theme)),
              const SizedBox(width: AppSpacing.sp2),
              Expanded(child: _statCard('Backlogs', '${profile?.activeBacklogs ?? 0}', brandTheme, theme)),
            ],
          ),
          const SizedBox(height: AppSpacing.sp2),
          Row(
            children: [
              Expanded(child: _statCard('Semester', semester != null ? '$semester' : '—', brandTheme, theme)),
              const SizedBox(width: AppSpacing.sp2),
              Expanded(child: _statCard('Graduation', profile?.graduationYear != null ? '${profile!.graduationYear}' : '—', brandTheme, theme)),
            ],
          ),
          const SizedBox(height: AppSpacing.sp6),

          // ── Personal Information ──────────────────────────────────────
          _infoCard(
            icon: Icons.person_outline_rounded,
            title: 'Personal Information',
            theme: theme,
            brandTheme: brandTheme,
            onEdit: () => context.push('/student/profile-edit', extra: 0),
            rows: [
              _infoRow('Name', name),
              _infoRow('College Email', profile?.email ?? '—'),
              _infoRow('Phone', profile?.phone ?? '—'),
              _infoRow('Date of Birth', profile?.dob != null
                  ? '${profile!.dob!.day}/${profile.dob!.month}/${profile.dob!.year}'
                  : '—'),
              _infoRow('Gender', profile?.gender ?? '—'),
            ],
          ),
          const SizedBox(height: AppSpacing.sp3),

          // ── Academic Information ──────────────────────────────────────
          _infoCard(
            icon: Icons.school_outlined,
            title: 'Academic Information',
            theme: theme,
            brandTheme: brandTheme,
            onEdit: () => context.push('/student/profile-edit', extra: 1),
            rows: [
              _infoRow('USN', usn.isNotEmpty ? usn : '—'),
              _infoRow('Department', dept.isNotEmpty ? dept : '—'),
              _infoRow('Semester', semester != null ? '$semester' : '—'),
              _infoRow('Section', section ?? '—'),
              _infoRow('Admission Year', profile?.admissionYear != null ? '${profile!.admissionYear}' : '—'),
              _infoRow('Graduation Year', profile?.graduationYear != null ? '${profile!.graduationYear}' : '—'),
            ],
          ),
          const SizedBox(height: AppSpacing.sp3),

          // ── Education ─────────────────────────────────────────────────
          _infoCard(
            icon: Icons.menu_book_outlined,
            title: 'Education',
            theme: theme,
            brandTheme: brandTheme,
            onEdit: () => context.push('/student/profile-edit', extra: 2),
            rows: [
              _infoRow('SSLC Percentage', profile?.tenthPercent != null ? '${profile!.tenthPercent}%' : '—'),
              _infoRow('PUC / Diploma', profile?.twelfthOrDiplomaPercent != null ? '${profile!.twelfthOrDiplomaPercent}%' : '—'),
              _infoRow('CGPA', cgpa != null ? cgpa.toStringAsFixed(2) : '—'),
              _infoRow('Active Backlogs', '${profile?.activeBacklogs ?? 0}'),
            ],
          ),
          const SizedBox(height: AppSpacing.sp3),

          // ── Resume ────────────────────────────────────────────────────
          _resumeCard(profile, theme, brandTheme),
          const SizedBox(height: AppSpacing.sp6),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name, AppBrandTheme brandTheme) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: brandTheme.brassGradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
          style: GoogleFonts.fraunces(fontSize: 36, color: brandTheme.onBrass, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _verificationBadge(ApprovalStatus? status, AppBrandTheme brandTheme) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case ApprovalStatus.approved:
        bgColor = brandTheme.statusShortlisted.withValues(alpha: 0.15);
        textColor = brandTheme.statusShortlisted;
        label = 'Verified';
        icon = Icons.verified_rounded;
        break;
      case ApprovalStatus.rejected:
        bgColor = brandTheme.statusRejected.withValues(alpha: 0.15);
        textColor = brandTheme.statusRejected;
        label = 'Rejected';
        icon = Icons.cancel_rounded;
        break;
      default:
        bgColor = brandTheme.statusPending.withValues(alpha: 0.15);
        textColor = brandTheme.statusPending;
        label = 'Pending Verification';
        icon = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, AppBrandTheme brandTheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sp3, horizontal: AppSpacing.sp3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: GoogleFonts.ibmPlexMono(fontSize: 10, fontWeight: FontWeight.w600, color: brandTheme.textMuted)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, AppBrandTheme brandTheme) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w600, color: brandTheme.textMuted, letterSpacing: 0.5),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required ThemeData theme,
    required AppBrandTheme brandTheme,
    required List<Widget> rows,
    VoidCallback? onEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: brandTheme.brassPrimary),
              const SizedBox(width: AppSpacing.sp2),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sp3, vertical: AppSpacing.sp1),
                    decoration: BoxDecoration(
                      color: brandTheme.brassSoft.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 14, color: brandTheme.brassPrimary),
                        const SizedBox(width: 4),
                        Text('Edit',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: brandTheme.brassPrimary,
                            )),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sp3),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _driveItem(Drive drive, bool isApplied, ThemeData theme, AppBrandTheme brandTheme) {
    final daysLeft = drive.applicationDeadline.difference(DateTime.now()).inDays;
    final deadlineText = daysLeft > 0 ? 'Deadline in ${daysLeft}d' : 'Deadline today';
    final details = '${drive.roleTitle} · ${drive.ctcOrStipend}';

    return GestureDetector(
      onTap: () {
        if (isApplied) {
          // Navigate to Timeline tab (index 2) to see application status
          ref.read(studentDashboardTabProvider.notifier).state = 2;
        } else {
          context.push('/student/drive-details', extra: drive);
        }
      },
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drive.companyName, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(details, style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
                  const SizedBox(height: 4),
                  Text(deadlineText, style: GoogleFonts.ibmPlexMono(fontSize: 11, color: brandTheme.brassPrimary)),
                ],
              ),
            ),
            isApplied
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: brandTheme.statusShortlisted.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 14, color: brandTheme.statusShortlisted),
                        const SizedBox(width: 4),
                        Text('Applied', style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: brandTheme.statusShortlisted,
                        )),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: brandTheme.brassGradient,
                      borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                    ),
                    child: Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: brandTheme.onBrass)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _resumeCard(UserProfile? profile, ThemeData theme, AppBrandTheme brandTheme) {
    final hasResume = profile?.resumeUrl != null && (profile?.resumeUrl ?? '').isNotEmpty;
    final fileName = hasResume ? FileNameExtractor.extract(profile!.resumeUrl!) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 18, color: brandTheme.brassPrimary),
              const SizedBox(width: AppSpacing.sp2),
              Text('Resume', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: AppSpacing.sp3),
          if (hasResume) ...[
            _infoRow('Status', '✓ Uploaded'),
            _infoRow('File', fileName ?? 'Resume'),
            _infoRow('Uploaded On', FileNameExtractor.formatDate(profile?.updatedAt)),
            const SizedBox(height: AppSpacing.sp3),
            Row(
              children: [
                Expanded(
                  child: _resumeActionButton(
                    label: 'View',
                    icon: Icons.open_in_new_rounded,
                    onTap: () { if (profile?.resumeUrl != null) _openResume(profile!.resumeUrl!); },
                    brandTheme: brandTheme,
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.sp2),
                Expanded(
                  child: _resumeActionButton(
                    label: 'Replace',
                    icon: Icons.swap_horiz_rounded,
                    onTap: () => context.push('/student/profile-edit', extra: 3),
                    brandTheme: brandTheme,
                    isPrimary: false,
                  ),
                ),
              ],
            ),
          ] else ...[
            _infoRow('Status', 'Not uploaded'),
            const SizedBox(height: AppSpacing.sp3),
            GestureDetector(
              onTap: () => context.push('/student/profile-edit', extra: 3),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: brandTheme.brassGradient,
                  borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                ),
                child: Center(
                  child: Text('Upload Resume', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: brandTheme.onBrass)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resumeActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required AppBrandTheme brandTheme,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isPrimary ? brandTheme.brassGradient : null,
          color: isPrimary ? null : Colors.transparent,
          border: isPrimary ? null : Border.all(color: brandTheme.cardBorder),
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isPrimary ? brandTheme.onBrass : brandTheme.textMuted),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPrimary ? brandTheme.onBrass : brandTheme.textMuted,
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _openResume(String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      try {
        final gdocUri = Uri.parse('https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(url)}');
        await launchUrl(gdocUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open resume. Please check internet connection or PDF viewer.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

}

