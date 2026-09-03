import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/skeleton_loader.dart';
import '../providers/department_analytics_provider.dart';

class DepartmentAnalyticsScreen extends ConsumerStatefulWidget {
  final String department;
  const DepartmentAnalyticsScreen({required this.department, super.key});

  @override
  ConsumerState<DepartmentAnalyticsScreen> createState() =>
      _DepartmentAnalyticsScreenState();
}

class _DepartmentAnalyticsScreenState
    extends ConsumerState<DepartmentAnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final analyticsAsync =
        ref.watch(departmentAnalyticsProvider(widget.department));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/faculty');
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/faculty');
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Department Analytics',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              Text(
                widget.department,
                style: GoogleFonts.inter(
                    fontSize: 12, color: brandTheme.textMuted),
              ),
            ],
          ),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => ref.invalidate(
                departmentAnalyticsProvider(widget.department)),
          ),
        ],
      ),
      body: analyticsAsync.when(
        data: (data) => _buildBody(data, theme, brandTheme),
        loading: () => _buildLoadingSkeleton(theme, brandTheme),
        error: (e, st) => _buildErrorState(e, theme, brandTheme),
      ),
    ),
  );
  }

  // ── Error State ────────────────────────────────────────────────────
  // Only shown when the provider itself throws (network unreachable etc.).
  // Individual query errors are shown as inline cards inside _buildBody.
  Widget _buildErrorState(
      Object error, ThemeData theme, AppBrandTheme brandTheme) {
    // Show the REAL error message — never mask it with a generic string.
    final rawMessage = error.toString();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: brandTheme.statusRejected.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 36, color: brandTheme.statusRejected),
            ),
            const SizedBox(height: AppSpacing.sp4),
            Text('Failed to load analytics',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sp2),
            // Show full error in debug mode; summary in release
            Text(
              kDebugMode
                  ? rawMessage
                  : 'An error occurred loading analytics. Check logs for details.',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: brandTheme.textMuted),
              textAlign: TextAlign.center,
              maxLines: kDebugMode ? 8 : 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sp4),
            GestureDetector(
              onTap: () => ref.invalidate(
                  departmentAnalyticsProvider(widget.department)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: brandTheme.brassGradient,
                  borderRadius: BorderRadius.circular(AppShapes.radiusFab),
                ),
                child: Text('Retry',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: brandTheme.onBrass)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main Body ──────────────────────────────────────────────────────
  // Even when some queries fail, the page renders with partial data.
  // Failed widgets are replaced by inline error cards with a retry button.
  Widget _buildBody(
      DepartmentAnalyticsData data, ThemeData theme, AppBrandTheme brandTheme) {
    final hasData = data.eligibleStudents > 0 || data.drives.isNotEmpty;
    final errors = data.queryErrors;

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(departmentAnalyticsProvider(widget.department)),
      color: brandTheme.brassPrimary,
      backgroundColor: theme.colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + AppSpacing.sp3,
          left: AppSpacing.sp5,
          right: AppSpacing.sp5,
          bottom: 110,
        ),
        children: [
          // ── Global query-error banner (debug only) ───────────────
          if (errors.isNotEmpty && kDebugMode) ...[
            _debugErrorBanner(errors, theme, brandTheme),
            const SizedBox(height: AppSpacing.sp4),
          ],

          if (!hasData && errors.isEmpty) ...[
            _buildEmptyState(theme, brandTheme),
          ] else ...[
            // ── Overview: depends on 'profiles' + 'applications' ─
            _buildSectionTitle('Overview', brandTheme),
            const SizedBox(height: AppSpacing.sp3),
            if (errors.containsKey('profiles') ||
                errors.containsKey('applications'))
              _inlineQueryErrorCard(
                  'profiles',
                  errors,
                  theme,
                  brandTheme,
                  fallback: _buildOverviewCards(data, theme, brandTheme))
            else
              _buildOverviewCards(data, theme, brandTheme),
            const SizedBox(height: AppSpacing.sp6),

            // ── Recruitment Funnel: depends on drive_rounds + application_round_status
            if (data.roundNames.isNotEmpty ||
                errors.containsKey('drive_rounds') ||
                errors.containsKey('application_round_status')) ...[
              _buildSectionTitle('Recruitment Funnel', brandTheme),
              const SizedBox(height: AppSpacing.sp3),
              if (errors.containsKey('drive_rounds') ||
                  errors.containsKey('application_round_status'))
                _inlineQueryErrorCard(
                    'drive_rounds', errors, theme, brandTheme)
              else if (data.roundNames.isNotEmpty)
                _buildFunnel(data, theme, brandTheme),
              const SizedBox(height: AppSpacing.sp6),
            ],

            // ── Drive Performance: depends on 'drives' ────────────
            _buildSectionTitle('Drive Performance', brandTheme),
            const SizedBox(height: AppSpacing.sp3),
            if (errors.containsKey('drives'))
              _inlineQueryErrorCard('drives', errors, theme, brandTheme)
            else if (data.drives.isEmpty)
              _emptySection('No drives found', theme, brandTheme)
            else
              ...data.drives.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sp3),
                    child: _buildDriveCard(d, theme, brandTheme),
                  )),
            const SizedBox(height: AppSpacing.sp6),

            // ── Placement Status: depends on 'applications' ───────
            _buildSectionTitle('Placement Status', brandTheme),
            const SizedBox(height: AppSpacing.sp3),
            if (errors.containsKey('applications'))
              _inlineQueryErrorCard('applications', errors, theme, brandTheme)
            else
              _buildPlacementDonut(data, theme, brandTheme),
            const SizedBox(height: AppSpacing.sp6),

            // ── Round Performance: depends on application_round_status
            if (data.roundPerformance.isNotEmpty ||
                errors.containsKey('application_round_status')) ...[
              _buildSectionTitle('Round Performance', brandTheme),
              const SizedBox(height: AppSpacing.sp3),
              if (errors.containsKey('application_round_status'))
                _inlineQueryErrorCard(
                    'application_round_status', errors, theme, brandTheme)
              else
                _buildRoundPerformance(data, theme, brandTheme),
              const SizedBox(height: AppSpacing.sp6),
            ],

            // ── Students Needing Attention: depends on 'profiles' ─
            _buildSectionTitle('Students Needing Attention', brandTheme),
            const SizedBox(height: AppSpacing.sp3),
            if (errors.containsKey('profiles'))
              _inlineQueryErrorCard('profiles', errors, theme, brandTheme)
            else
              _buildAttentionCards(data, theme, brandTheme),
            const SizedBox(height: AppSpacing.sp6),

            // ── Quick Insights: depends on drives + applications ──
            _buildSectionTitle('Quick Insights', brandTheme),
            const SizedBox(height: AppSpacing.sp3),
            _buildQuickInsights(data, theme, brandTheme),
          ],
        ],
      ),
    );
  }

  // ── Inline per-widget error card ───────────────────────────────────
  // Shows the actual failing query name + exception text.
  // In debug mode it shows the full Postgrest exception; in release,
  // just a short message.
  Widget _inlineQueryErrorCard(
    String primaryQueryName,
    Map<String, String> errors,
    ThemeData theme,
    AppBrandTheme brandTheme, {
    Widget? fallback,
  }) {
    // Collect all errors for queries that this widget depends on
    final relevantErrors = errors.entries
        .where((e) => e.key == primaryQueryName)
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: brandTheme.statusRejected.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(
            color: brandTheme.statusRejected.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: brandTheme.statusRejected),
              const SizedBox(width: AppSpacing.sp2),
              Expanded(
                child: Text(
                  'Widget failed — query: $primaryQueryName',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: brandTheme.statusRejected,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(
                    departmentAnalyticsProvider(widget.department)),
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('Retry',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: brandTheme.brassPrimary)),
              ),
            ],
          ),
          if (kDebugMode && relevantErrors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sp2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sp2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
              ),
              child: Text(
                relevantErrors,
                style: GoogleFonts.ibmPlexMono(
                    fontSize: 10, color: brandTheme.textMuted),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          // Render fallback widget (e.g., overview cards with zeros) if provided
          if (fallback != null) ...[
            const SizedBox(height: AppSpacing.sp3),
            fallback,
          ],
        ],
      ),
    );
  }

  // ── Debug error banner — lists ALL failing queries ─────────────────
  Widget _debugErrorBanner(
    Map<String, String> errors,
    ThemeData theme,
    AppBrandTheme brandTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp3),
      decoration: BoxDecoration(
        color: brandTheme.statusRejected.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(
            color: brandTheme.statusRejected.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report_rounded,
                  size: 16, color: brandTheme.statusRejected),
              const SizedBox(width: AppSpacing.sp2),
              Text(
                'DEBUG: ${errors.length} query error(s)',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: brandTheme.statusRejected),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sp2),
          ...errors.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${e.key}: ${e.value}',
                  style: GoogleFonts.ibmPlexMono(
                      fontSize: 10, color: brandTheme.textMuted),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
        ],
      ),
    );
  }

  // ── Empty section placeholder ──────────────────────────────────────
  Widget _emptySection(
      String message, ThemeData theme, AppBrandTheme brandTheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Center(
        child: Text(message,
            style:
                GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────
  Widget _buildEmptyState(ThemeData theme, AppBrandTheme brandTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: brandTheme.brassPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.analytics_outlined,
                  size: 40, color: brandTheme.brassPrimary),
            ),
            const SizedBox(height: AppSpacing.sp5),
            Text('No Analytics Data Yet',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sp2),
            Text(
              'Analytics will appear once students are approved,\ndrives are configured, and applications are received.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: brandTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Title ──────────────────────────────────────────────────
  Widget _buildSectionTitle(String title, AppBrandTheme brandTheme) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: brandTheme.brassPrimary,
        letterSpacing: 1.2,
      ),
    );
  }

  // ── Section 1 — Overview Cards ─────────────────────────────────────
  Widget _buildOverviewCards(
      DepartmentAnalyticsData data, ThemeData theme, AppBrandTheme brandTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final crossAxisCount = isWide ? 4 : 2;
        final childAspectRatio = isWide ? 1.5 : 1.25;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sp3,
          crossAxisSpacing: AppSpacing.sp3,
          childAspectRatio: childAspectRatio,
          children: [
            _statCard(
              icon: Icons.people_rounded,
              label: 'Eligible',
              value: '${data.eligibleStudents}',
              subtitle: widget.department,
              color: brandTheme.brassPrimary,
              theme: theme,
              brandTheme: brandTheme,
            ),
            _statCard(
              icon: Icons.assignment_turned_in_rounded,
              label: 'Applied',
              value: '${data.appliedStudents}',
              subtitle: '${data.departmentApplicationRate.toStringAsFixed(1)}%',
              color: brandTheme.statusApplied,
              theme: theme,
              brandTheme: brandTheme,
            ),
            _statCard(
              icon: Icons.emoji_events_rounded,
              label: 'Offers',
              value: '${data.offersReceived}',
              subtitle: 'Received',
              color: brandTheme.statusShortlisted,
              theme: theme,
              brandTheme: brandTheme,
            ),
            _statCard(
              icon: Icons.pie_chart_rounded,
              label: 'Placement %',
              value: '${data.placementPercentage.toStringAsFixed(1)}%',
              subtitle: 'Selected / Eligible',
              color: brandTheme.statusShortlisted,
              theme: theme,
              brandTheme: brandTheme,
            ),
          ],
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required ThemeData theme,
    required AppBrandTheme brandTheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(subtitle,
              style: GoogleFonts.inter(
                  fontSize: 10, color: brandTheme.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ── Section 2 — Recruitment Funnel ─────────────────────────────────
  Widget _buildFunnel(
      DepartmentAnalyticsData data, ThemeData theme, AppBrandTheme brandTheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Column(
        children: [
          _funnelRow('Eligible', data.eligibleStudents, data.eligibleStudents,
              brandTheme,
              isTop: true),
          ...List.generate(data.roundNames.length, (i) {
            final count =
                i < data.funnelCounts.length ? data.funnelCounts[i] : 0;
            return _funnelRow(
              data.roundNames[i],
              count,
              data.eligibleStudents,
              brandTheme,
            );
          }),
          _funnelRow(
            'Final Selected',
            data.selectedCount,
            data.eligibleStudents,
            brandTheme,
            isBottom: true,
            color: brandTheme.statusShortlisted,
          ),
        ],
      ),
    );
  }

  Widget _funnelRow(String label, int count, int max,
      AppBrandTheme brandTheme,
      {bool isTop = false, bool isBottom = false, Color? color}) {
    final fraction = max > 0 ? count / max : 0.0;
    final barColor = color ?? brandTheme.brassPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Flexible(
            child: Text(label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.right),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 24,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        height: 24,
                        width:
                            constraints.maxWidth * fraction.clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              barColor.withValues(alpha: 0.6),
                              barColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text('$count',
                style: GoogleFonts.ibmPlexMono(
                    fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  // ── Section 3 — Drive Performance Card ─────────────────────────────
  Widget _buildDriveCard(
      DriveAnalytics drive, ThemeData theme, AppBrandTheme brandTheme) {
    return _ExpandableCard(
      header: Column(
        children: [
          Row(
            children: [
              _companyInitials(drive.companyName, brandTheme),
              const SizedBox(width: AppSpacing.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(drive.companyName,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(drive.role,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: brandTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _statusBadge(drive.status, brandTheme),
            ],
          ),
          const SizedBox(height: AppSpacing.sp3),
          Row(
            children: [
              _miniStat('Applied', '${drive.applied}', brandTheme),
              _miniStat('Attended', '${drive.attendance}', brandTheme),
              _miniStat('Qualified', '${drive.qualified}', brandTheme),
              _miniStat('Rejected', '${drive.rejected}', brandTheme),
              _miniStat('Selected', '${drive.selected}',
                  brandTheme,
                  highlight: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sp3),
          Row(
            children: [
              Text('Selection',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: brandTheme.textMuted)),
              const SizedBox(width: AppSpacing.sp2),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: drive.selectionPercent / 100,
                    minHeight: 6,
                    backgroundColor:
                        brandTheme.cardBorder.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation(
                        brandTheme.statusShortlisted),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sp2),
              Text('${drive.selectionPercent.toStringAsFixed(1)}%',
                  style: GoogleFonts.ibmPlexMono(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
      expanded: drive.rounds.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: brandTheme.dividerColor),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sp3),
                  child: Text('ROUND-WISE BREAKDOWN',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: brandTheme.brassPrimary,
                          letterSpacing: 1)),
                ),
                const SizedBox(height: AppSpacing.sp2),
                ...drive.rounds.map((r) => Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sp1),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(r.roundName,
                                style: GoogleFonts.inter(fontSize: 13)),
                          ),
                          Expanded(
                            flex: 5,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: r.entered > 0
                                    ? r.qualified / r.entered
                                    : 0,
                                minHeight: 8,
                                backgroundColor: brandTheme.cardBorder
                                    .withValues(alpha: 0.5),
                                valueColor: AlwaysStoppedAnimation(
                                    brandTheme.statusShortlisted),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sp2),
                          SizedBox(
                            width: 50,
                            child: Text('${r.qualified} / ${r.entered}',
                                style: GoogleFonts.ibmPlexMono(fontSize: 11),
                                textAlign: TextAlign.right),
                          ),
                        ],
                      ),
                    )),
              ],
            )
          : null,
    );
  }

  Widget _companyInitials(String name, AppBrandTheme brandTheme) {
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: brandTheme.brassPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: brandTheme.brassPrimary),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, AppBrandTheme brandTheme,
      {bool highlight = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: highlight ? brandTheme.statusShortlisted : null)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 9, color: brandTheme.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, AppBrandTheme brandTheme) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
      case 'ongoing':
      case 'open':
        color = brandTheme.statusShortlisted;
        break;
      case 'completed':
      case 'closed':
        color = brandTheme.textMuted;
        break;
      case 'cancelled':
        color = brandTheme.statusRejected;
        break;
      default:
        color = brandTheme.statusApplied;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(status.toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ── Section 4 — Placement Donut ────────────────────────────────────
  Widget _buildPlacementDonut(
      DepartmentAnalyticsData data, ThemeData theme, AppBrandTheme brandTheme) {
    final total = data.selectedCount +
        data.inProcessCount +
        data.rejectedCount +
        data.notAppliedCount;

    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sp6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
          border: Border.all(color: brandTheme.cardBorder),
        ),
        child: Center(
          child: Text('No placement data available',
              style: GoogleFonts.inter(
                  fontSize: 13, color: brandTheme.textMuted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 320;
          if (isNarrow) {
            return Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 30,
                      sections: [
                        PieChartSectionData(
                          value: data.selectedCount.toDouble(),
                          color: brandTheme.statusShortlisted,
                          radius: 18,
                          title: '',
                        ),
                        PieChartSectionData(
                          value: data.inProcessCount.toDouble(),
                          color: brandTheme.brassPrimary,
                          radius: 18,
                          title: '',
                        ),
                        PieChartSectionData(
                          value: data.rejectedCount.toDouble(),
                          color: brandTheme.statusRejected,
                          radius: 18,
                          title: '',
                        ),
                        PieChartSectionData(
                          value: data.notAppliedCount.toDouble(),
                          color: brandTheme.textMuted.withValues(alpha: 0.5),
                          radius: 18,
                          title: '',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem('Selected', data.selectedCount, total,
                        brandTheme.statusShortlisted, brandTheme),
                    const SizedBox(height: AppSpacing.sp2),
                    _legendItem('In Process', data.inProcessCount, total,
                        brandTheme.brassPrimary, brandTheme),
                    const SizedBox(height: AppSpacing.sp2),
                    _legendItem('Rejected', data.rejectedCount, total,
                        brandTheme.statusRejected, brandTheme),
                    const SizedBox(height: AppSpacing.sp2),
                    _legendItem('Not Applied', data.notAppliedCount, total,
                        brandTheme.textMuted.withValues(alpha: 0.5), brandTheme),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: [
                      PieChartSectionData(
                        value: data.selectedCount.toDouble(),
                        color: brandTheme.statusShortlisted,
                        radius: 18,
                        title: '',
                      ),
                      PieChartSectionData(
                        value: data.inProcessCount.toDouble(),
                        color: brandTheme.brassPrimary,
                        radius: 18,
                        title: '',
                      ),
                      PieChartSectionData(
                        value: data.rejectedCount.toDouble(),
                        color: brandTheme.statusRejected,
                        radius: 18,
                        title: '',
                      ),
                      PieChartSectionData(
                        value: data.notAppliedCount.toDouble(),
                        color: brandTheme.textMuted.withValues(alpha: 0.5),
                        radius: 18,
                        title: '',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendItem('Selected', data.selectedCount, total,
                        brandTheme.statusShortlisted, brandTheme),
                    const SizedBox(height: AppSpacing.sp2),
                    _legendItem('In Process', data.inProcessCount, total,
                        brandTheme.brassPrimary, brandTheme),
                    const SizedBox(height: AppSpacing.sp2),
                    _legendItem('Rejected', data.rejectedCount, total,
                        brandTheme.statusRejected, brandTheme),
                    const SizedBox(height: AppSpacing.sp2),
                    _legendItem('Not Applied', data.notAppliedCount, total,
                        brandTheme.textMuted.withValues(alpha: 0.5), brandTheme),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _legendItem(String label, int count, int total, Color color,
      AppBrandTheme brandTheme) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: AppSpacing.sp2),
        Expanded(
            child: Text(label,
                style: GoogleFonts.inter(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('$count ($pct%)',
              style: GoogleFonts.ibmPlexMono(
                  fontSize: 11, color: brandTheme.textMuted)),
        ),
      ],
    );
  }

  // ── Section 5 — Round Performance ──────────────────────────────────
  Widget _buildRoundPerformance(
      DepartmentAnalyticsData data, ThemeData theme, AppBrandTheme brandTheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sp3),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text('Round',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: brandTheme.textMuted))),
                Expanded(
                    flex: 2,
                    child: Text('Qualified',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: brandTheme.textMuted),
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('Rejected',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: brandTheme.textMuted),
                        textAlign: TextAlign.center)),
                Expanded(
                    flex: 2,
                    child: Text('Pass %',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: brandTheme.textMuted),
                        textAlign: TextAlign.right)),
              ],
            ),
          ),
          Divider(height: 1, color: brandTheme.dividerColor),
          ...data.roundPerformance.map((rp) => Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sp3),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(rp.roundName,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('${rp.qualified}',
                          style: GoogleFonts.ibmPlexMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: brandTheme.statusShortlisted),
                          textAlign: TextAlign.center),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('${rp.rejected}',
                          style: GoogleFonts.ibmPlexMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: brandTheme.statusRejected),
                          textAlign: TextAlign.center),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                          '${rp.passPercentage.toStringAsFixed(0)}%',
                          style: GoogleFonts.ibmPlexMono(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Section 6 — Students Needing Attention ─────────────────────────
  Widget _buildAttentionCards(
      DepartmentAnalyticsData data, ThemeData theme, AppBrandTheme brandTheme) {
    final items = <_AttentionItem>[
      if (data.profileIncomplete > 0)
        _AttentionItem(
          icon: Icons.person_off_rounded,
          label: 'Profile Incomplete',
          count: data.profileIncomplete,
          desc: 'Students with incomplete profiles',
          color: brandTheme.statusPending,
        ),
      _AttentionItem(
        icon: Icons.description_outlined,
        label: 'Resume Missing / Pending',
        count: data.resumeMissing,
        desc: data.resumeMissing > 0
            ? 'Students without an uploaded resume'
            : 'All student resumes uploaded',
        color: data.resumeMissing > 0 ? brandTheme.statusRejected : brandTheme.statusShortlisted,
      ),
    ];

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sp6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
          border: Border.all(color: brandTheme.cardBorder),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 32, color: brandTheme.statusShortlisted),
              const SizedBox(height: AppSpacing.sp2),
              Text('All students are in good standing',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: brandTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: items
          .map((item) => Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sp2),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                  border: Border.all(
                      color: brandTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppShapes.radiusSmall),
                      ),
                      child: Icon(item.icon, size: 20, color: item.color),
                    ),
                    const SizedBox(width: AppSpacing.sp3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(item.desc,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: brandTheme.textMuted)),
                          if (item.label.contains('Resume') && data.resumeMissingStudentNames.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Students: ${data.resumeMissingStudentNames.join(', ')}',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: brandTheme.statusRejected),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('${item.count}',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: item.color)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ── Section 7 — Quick Insights ─────────────────────────────────────
  Widget _buildQuickInsights(
      DepartmentAnalyticsData data, ThemeData theme, AppBrandTheme brandTheme) {
    final insights = <_InsightItem>[
      _InsightItem(
        icon: Icons.trending_up_rounded,
        label: 'Most Applied Drive',
        value: data.highestAppliedDrive,
        color: brandTheme.brassPrimary,
      ),
      _InsightItem(
        icon: Icons.attach_money_rounded,
        label: 'Highest Package',
        value: data.highestPackageDrive,
        color: brandTheme.statusShortlisted,
      ),
      _InsightItem(
        icon: Icons.trending_down_rounded,
        label: 'Lowest Participation',
        value: data.lowestParticipationDrive,
        color: brandTheme.statusPending,
      ),
      _InsightItem(
        icon: Icons.school_rounded,
        label: 'Avg CGPA',
        value: data.avgCgpa > 0 ? data.avgCgpa.toStringAsFixed(2) : '—',
        color: brandTheme.brassPrimary,
      ),
      _InsightItem(
        icon: Icons.percent_rounded,
        label: 'Application Rate',
        value: '${data.departmentApplicationRate.toStringAsFixed(1)}%',
        color: brandTheme.statusApplied,
      ),
      _InsightItem(
        icon: Icons.swap_vert_circle_rounded,
        label: 'Offer Conversion',
        value: '${data.offerConversionRate.toStringAsFixed(1)}%',
        color: brandTheme.statusShortlisted,
      ),
      _InsightItem(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Attendance Rate',
        value: '${data.attendancePercentage.toStringAsFixed(1)}%',
        color: brandTheme.brassPrimary,
      ),
    ];

    return Column(
      children: insights
          .map((item) => Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sp2),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius:
                      BorderRadius.circular(AppShapes.radiusStandard),
                  border: Border.all(color: brandTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppShapes.radiusSmall),
                      ),
                      child: Icon(item.icon, size: 18, color: item.color),
                    ),
                    const SizedBox(width: AppSpacing.sp3),
                    Expanded(
                      child: Text(item.label,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    Flexible(
                      child: Text(item.value,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ── Loading Skeleton ───────────────────────────────────────────────
  Widget _buildLoadingSkeleton(ThemeData theme, AppBrandTheme brandTheme) {
    return ListView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.sp3,
        left: AppSpacing.sp5,
        right: AppSpacing.sp5,
        bottom: 110,
      ),
      children: [
        Text('OVERVIEW',
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: brandTheme.brassPrimary,
                letterSpacing: 1.2)),
        const SizedBox(height: AppSpacing.sp3),
        _buildOverviewSkeletonRow(theme, brandTheme),
        const SizedBox(height: AppSpacing.sp2),
        _buildOverviewSkeletonRow(theme, brandTheme),
        const SizedBox(height: AppSpacing.sp6),
        ...List.generate(3, (_) => const SkeletonCardRow()),
      ],
    );
  }

  Widget _buildOverviewSkeletonRow(ThemeData theme, AppBrandTheme brandTheme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 100,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
              border: Border.all(color: brandTheme.cardBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 32, height: 32, borderRadius: 8),
                Spacer(),
                SkeletonLoader(width: 50, height: 18, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonLoader(width: 70, height: 10, borderRadius: 4),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sp3),
        Expanded(
          child: Container(
            height: 100,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
              border: Border.all(color: brandTheme.cardBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 32, height: 32, borderRadius: 8),
                Spacer(),
                SkeletonLoader(width: 50, height: 18, borderRadius: 4),
                SizedBox(height: 4),
                SkeletonLoader(width: 70, height: 10, borderRadius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────

class _AttentionItem {
  final IconData icon;
  final String label;
  final int count;
  final String desc;
  final Color color;
  const _AttentionItem(
      {required this.icon,
      required this.label,
      required this.count,
      required this.desc,
      required this.color});
}

class _InsightItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InsightItem(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
}

// ── Expandable Card ──────────────────────────────────────────────────

class _ExpandableCard extends StatefulWidget {
  final Widget header;
  final Widget? expanded;

  const _ExpandableCard({required this.header, this.expanded});

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.expanded != null
                ? () => setState(() => _expanded = !_expanded)
                : null,
            borderRadius:
                BorderRadius.circular(AppShapes.radiusStandard),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sp4),
              child: Column(
                children: [
                  widget.header,
                  if (widget.expanded != null) ...[
                    const SizedBox(height: AppSpacing.sp3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _expanded ? 'Hide Details' : 'View Details',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: brandTheme.brassPrimary),
                        ),
                        const SizedBox(width: AppSpacing.sp1),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration:
                              const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more_rounded,
                              size: 18,
                              color: brandTheme.brassPrimary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded && widget.expanded != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sp4, 0, AppSpacing.sp4, AppSpacing.sp4),
              child: widget.expanded,
            ),
        ],
      ),
    );
  }
}

