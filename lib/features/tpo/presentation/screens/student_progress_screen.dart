import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../student/domain/entities/drive.dart';
import '../../domain/entities/drive_round.dart';
import '../providers/tpo_provider.dart';

class StudentProgressScreen extends ConsumerWidget {
  final Drive drive;
  final String applicationId;
  final String studentName;

  const StudentProgressScreen({
    required this.drive,
    required this.applicationId,
    required this.studentName,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final progressAsync = ref.watch(studentRoundProgressProvider(applicationId));
    final roundsAsync = ref.watch(driveRoundsProvider(drive.id));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/tpo');
        }
      },
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/tpo');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progress', style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
            Text(
              '$studentName · ${drive.roleTitle}',
              style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: roundsAsync.when(
        data: (rounds) {
          return progressAsync.when(
            data: (progress) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.sp5),
                children: [
                  _driveHeader(context, brandTheme),
                  const SizedBox(height: AppSpacing.sp5),
                  _roundTimeline(context, brandTheme, rounds, progress),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading progress: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading rounds: $e')),
      ),
    ),
  );
  }

  Widget _driveHeader(BuildContext context, AppBrandTheme brandTheme) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: brandTheme.brassSoft,
            child: Text(
              drive.companyName.isNotEmpty ? drive.companyName.substring(0, 1).toUpperCase() : '?',
              style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(drive.companyName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(drive.roleTitle, style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted)),
                if (drive.ctcOrStipend.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(drive.ctcOrStipend, style: GoogleFonts.ibmPlexMono(fontSize: 12, color: brandTheme.brassPrimary)),
                ],
              ],
            ),
          ),
          _statusChip(drive.status, brandTheme),
        ],
      ),
    );
  }

  Widget _statusChip(String status, AppBrandTheme brandTheme) {
    final (color, label) = switch (status.toLowerCase()) {
      'active' => (brandTheme.statusShortlisted, 'Active'),
      'completed' => (brandTheme.statusShortlisted, 'Completed'),
      'upcoming' => (brandTheme.statusPending, 'Upcoming'),
      _ => (brandTheme.textMuted, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _roundTimeline(BuildContext context, AppBrandTheme brandTheme, List<dynamic> rounds, List<Map<String, dynamic>> progress) {
    final theme = Theme.of(context);

    if (rounds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brandTheme.cardBorder),
        ),
        child: Center(
          child: Text(
            'No rounds configured for this drive',
            style: GoogleFonts.inter(color: brandTheme.textMuted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recruitment Rounds',
          style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sp4),
        ...List.generate(rounds.length, (index) {
          final dynamic roundObj = rounds[index];
          final String roundId = roundObj is DriveRound
              ? roundObj.id
              : (roundObj is Map ? (roundObj['id']?.toString() ?? '') : '');
          final int roundNumber = roundObj is DriveRound
              ? roundObj.roundNumber
              : (roundObj is Map ? (roundObj['round_number'] as int? ?? (index + 1)) : (index + 1));
          final String roundName = roundObj is DriveRound
              ? roundObj.roundName
              : (roundObj is Map ? (roundObj['round_name'] as String? ?? 'Round ${index + 1}') : 'Round ${index + 1}');

          // Find progress for this round
          final roundProgress = progress.firstWhere(
            (p) => p['round_id'] == roundId,
            orElse: () => <String, dynamic>{},
          );
          final attended = roundProgress['attended'] as bool? ?? false;
          final result = roundProgress['result'] as String? ?? 'pending';
          final remarks = roundProgress['remarks'] as String?;

          final isLast = index == rounds.length - 1;
          final isCompleted = attended || result == 'selected' || result == 'passed' || result == 'cleared';
          final isFailed = result == 'rejected' || result == 'failed' || result == 'not_selected';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _roundDot(isCompleted, isFailed, brandTheme),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      color: isCompleted ? brandTheme.brassPrimary.withValues(alpha: 0.5) : brandTheme.cardBorder,
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? brandTheme.brassPrimary.withValues(alpha: 0.05)
                        : isFailed
                            ? brandTheme.statusRejected.withValues(alpha: 0.05)
                            : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted
                          ? brandTheme.brassPrimary.withValues(alpha: 0.3)
                          : isFailed
                              ? brandTheme.statusRejected.withValues(alpha: 0.3)
                              : brandTheme.cardBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: brandTheme.brassPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Round $roundNumber',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: brandTheme.brassPrimary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              roundName,
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          _roundResultChip(result, brandTheme),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _roundDetailRow('Status', _roundStatusLabel(result, attended), brandTheme),
                      if (attended && roundProgress['updated_at'] != null)
                        _roundDetailRow(
                          'Completed',
                          '${DateTime.parse(roundProgress['updated_at']).day}/${DateTime.parse(roundProgress['updated_at']).month}/${DateTime.parse(roundProgress['updated_at']).year}',
                          brandTheme,
                        ),
                      if (remarks != null && remarks.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: brandTheme.statusPending.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.note_rounded, size: 14, color: brandTheme.statusPending),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  remarks,
                                  style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _roundDot(bool completed, bool failed, AppBrandTheme brandTheme) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: completed
            ? brandTheme.statusShortlisted
            : failed
                ? brandTheme.statusRejected
                : brandTheme.cardBorder,
        shape: BoxShape.circle,
        border: Border.all(
          color: completed
              ? brandTheme.statusShortlisted
              : failed
                  ? brandTheme.statusRejected
                  : brandTheme.cardBorder,
          width: 2,
        ),
      ),
      child: completed
          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
          : failed
              ? const Icon(Icons.close_rounded, size: 12, color: Colors.white)
              : const SizedBox.shrink(),
    );
  }

  Widget _roundResultChip(String result, AppBrandTheme brandTheme) {
    final (color, label, icon) = switch (result.toLowerCase()) {
      'cleared' => (brandTheme.statusShortlisted, 'Cleared', Icons.check_circle_rounded),
      'selected' => (brandTheme.statusShortlisted, 'Selected', Icons.check_circle_rounded),
      'passed' => (brandTheme.statusShortlisted, 'Passed', Icons.check_circle_rounded),
      'rejected' || 'failed' || 'not_selected' => (brandTheme.statusRejected, 'Failed', Icons.cancel_rounded),
      _ => (brandTheme.statusPending, 'Pending', Icons.schedule_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  String _roundStatusLabel(String result, bool attended) {
    if (!attended && result == 'pending') return 'Not attended';
    if (attended && result == 'pending') return 'Attended';
    return result[0].toUpperCase() + result.substring(1);
  }

  Widget _roundDetailRow(String label, String value, AppBrandTheme brandTheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.ibmPlexMono(fontSize: 11, color: brandTheme.textMuted),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
