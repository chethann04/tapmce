import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/file_name_extractor.dart';
import '../providers/student_timeline_provider.dart';

/// Unhidden, Beautifully Rearranged & Readable Application Tracker
class StudentApplicationTimelineScreen extends ConsumerWidget {
  const StudentApplicationTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final timelineAsync = ref.watch(studentTimelineProvider);
    final topPadding = MediaQuery.of(context).padding.top;

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
      body: timelineAsync.when(
        data: (applications) {
          if (applications.isEmpty) {
            return _emptyState(context, theme, brandTheme, topPadding);
          }
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: topPadding + AppSpacing.sp4,
                    left: AppSpacing.sp5,
                    right: AppSpacing.sp5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Application Tracker',
                        style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Structured recruitment journey and stage progress',
                        style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sp5, AppSpacing.sp4, AppSpacing.sp5, 110,
                ),
                sliver: SliverList.separated(
                  itemCount: applications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sp5),
                  itemBuilder: (_, i) => _StructuredApplicationCard(data: applications[i]),
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding + 100),
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding + 100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: brandTheme.statusRejected),
                const SizedBox(height: 12),
                Text('Failed to load tracker', style: GoogleFonts.inter(fontSize: 14)),
                const SizedBox(height: 8),
                Text(e.toString(), style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _emptyState(BuildContext context, ThemeData theme, AppBrandTheme brandTheme, double topPadding) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: topPadding + 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: brandTheme.brassSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.timeline_rounded, size: 40, color: brandTheme.brassPrimary),
            ),
            const SizedBox(height: AppSpacing.sp4),
            Text('No active applications',
                style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Apply to upcoming campus drives to track your progress.',
              style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sp5),
            GestureDetector(
              onTap: () => context.go('/student'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: brandTheme.brassGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Explore Drives',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// STRUCTURED APPLICATION CARD
// ──────────────────────────────────────────────────────────────────────────────

class _StructuredApplicationCard extends StatelessWidget {
  final ApplicationTimelineData data;
  const _StructuredApplicationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final (statusBg, statusFg, statusTitle) = _getOverallStatus(brandTheme);
    final resumeName = data.resumeUrl.isNotEmpty ? FileNameExtractor.extract(data.resumeUrl) : 'Default Resume';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Top Header: Company, Role & Status ─────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: brandTheme.brassSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      data.companyName.isNotEmpty ? data.companyName[0].toUpperCase() : 'C',
                      style: GoogleFonts.fraunces(
                          fontSize: 20, fontWeight: FontWeight.w700, color: brandTheme.brassPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.companyName,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(data.roleTitle,
                          style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      statusTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: statusFg),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // ── 2. Key Details Grid: Date & Attached Resume PDF ────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                // Applied Date Block
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: brandTheme.textMuted),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('APPLIED DATE',
                              style: GoogleFonts.ibmPlexMono(
                                  fontSize: 9, fontWeight: FontWeight.w700, color: brandTheme.textMuted)),
                          Text(
                            DateFormat('dd MMM yyyy').format(data.appliedAt),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: brandTheme.cardBorder),
                const SizedBox(width: 12),
                // Resume PDF Block
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_rounded, size: 16, color: brandTheme.brassPrimary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ATTACHED RESUME',
                                style: GoogleFonts.ibmPlexMono(
                                    fontSize: 9, fontWeight: FontWeight.w700, color: brandTheme.textMuted)),
                            Text(
                              resumeName,
                              style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // ── 3. Rearranged Recruitment Stages Section ───────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Recruitment Stages',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Stage ${data.currentRound} of ${data.totalRounds}',
                      style: GoogleFonts.ibmPlexMono(
                          fontSize: 11, fontWeight: FontWeight.w700, color: brandTheme.brassPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (data.rounds.isEmpty)
                  Text(
                    'No stages configured yet.',
                    style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
                  )
                else
                  ...List.generate(data.rounds.length, (i) {
                    final round = data.rounds[i];
                    final roundId = round['id'] as String? ?? '';
                    final roundName = (round['round_name'] as String?)?.isNotEmpty == true
                        ? round['round_name'] as String
                        : 'Round ${i + 1}';
                    final progress = data.progressForRound(roundId);
                    final isLast = i == data.rounds.length - 1;
                    // currentRound is 1-indexed; rounds list is 0-indexed
                    final roundNumber = i + 1;
                    final isCurrent = roundNumber == data.currentRound;
                    // A round is "past" if it's before the current round
                    final isPast = roundNumber < data.currentRound;

                    return _stageNode(
                      roundName: roundName,
                      roundNum: roundNumber,
                      progress: progress,
                      isCurrent: isCurrent,
                      isPast: isPast,
                      isLast: isLast,
                      brandTheme: brandTheme,
                      theme: theme,
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageNode({
    required String roundName,
    required int roundNum,
    Map<String, dynamic>? progress,
    required bool isCurrent,
    required bool isPast,
    required bool isLast,
    required AppBrandTheme brandTheme,
    required ThemeData theme,
  }) {
    final result = progress?['result'] as String? ?? 'pending';
    final attended = progress?['attended'] as bool? ?? false;
    final (badgeColor, badgeText, iconData) = _getStageStatus(result, attended, isCurrent, isPast, isLast, brandTheme);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Line & Number Indicator
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(iconData, size: 12, color: Colors.white),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: brandTheme.cardBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Stage Title & Badge Box
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrent
                    ? brandTheme.brassPrimary.withValues(alpha: 0.05)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrent
                      ? brandTheme.brassPrimary.withValues(alpha: 0.4)
                      : brandTheme.cardBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$roundNum. $roundName',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, String) _getOverallStatus(AppBrandTheme brandTheme) {
    final status = data.status.toLowerCase();
    if (status == 'rejected' || status == 'not_selected') {
      return (brandTheme.statusRejected.withValues(alpha: 0.12), brandTheme.statusRejected, 'Not Selected');
    }
    if (status == 'selected') {
      return (brandTheme.statusShortlisted.withValues(alpha: 0.12), brandTheme.statusShortlisted, 'Offer Released');
    }
    // currentRound is always >= 1 (defaulted in provider); show "Stage N Active"
    return (brandTheme.brassPrimary.withValues(alpha: 0.12), brandTheme.brassPrimary, 'Stage ${data.currentRound} Active');
  }

  (Color, String, IconData) _getStageStatus(
      String result, bool attended, bool isCurrent, bool isPast, bool isLast, AppBrandTheme brandTheme) {
    final res = result.toLowerCase();
    final overallStatus = data.status.toLowerCase();

    // Explicit result from DB takes highest priority
    if (res == 'cleared' || res == 'passed' || res == 'selected' || res == 'offered' || (isLast && overallStatus == 'selected')) {
      if (isLast || res == 'selected' || res == 'offered' || overallStatus == 'selected') {
        return (brandTheme.statusShortlisted, 'Offered', Icons.emoji_events_rounded);
      }
      return (brandTheme.statusShortlisted, 'Cleared', Icons.check_rounded);
    }
    if (res == 'rejected' || res == 'failed' || res == 'not_selected' || overallStatus == 'rejected') {
      return (brandTheme.statusRejected, 'Not Selected', Icons.close_rounded);
    }
    // No explicit result yet — use position relative to currentRound
    if (isLast && (isCurrent || isPast) && overallStatus == 'selected') {
      return (brandTheme.statusShortlisted, 'Offered', Icons.emoji_events_rounded);
    }
    if (isCurrent) {
      return (brandTheme.brassPrimary, 'Active Stage', Icons.play_arrow_rounded);
    }
    if (isPast) {
      // Past round with no explicit result (edge case: data lag) — show as cleared
      return (brandTheme.statusShortlisted, 'Cleared', Icons.check_rounded);
    }
    return (brandTheme.cardBorder, 'Upcoming', Icons.schedule_rounded);
  }
}
