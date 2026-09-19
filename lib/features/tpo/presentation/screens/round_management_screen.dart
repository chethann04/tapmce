import 'package:go_router/go_router.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/services/email_notification_service.dart';
import '../../../../shared/presentation/widgets/subtle_divider.dart';
import '../../../student/domain/entities/drive.dart';
import '../../domain/entities/drive_round.dart';
import '../providers/tpo_provider.dart';

class RoundManagementScreen extends ConsumerStatefulWidget {
  final Drive drive;
  const RoundManagementScreen({required this.drive, super.key});

  @override
  ConsumerState<RoundManagementScreen> createState() =>
      _RoundManagementScreenState();
}

class _RoundManagementScreenState
    extends ConsumerState<RoundManagementScreen> {
  int? _selectedRoundNumber;
  String _searchQuery = '';
  String _filterStatus = 'all'; // 'all', 'current', 'completed', 'offered', 'rejected', 'absent'
  final Set<String> _selectedAppIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final roundsAsync = ref.watch(driveRoundsProvider(widget.drive.id));

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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Manage Recruitment',
              style: GoogleFonts.fraunces(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            Text(
              '${widget.drive.companyName} · ${widget.drive.roleTitle}',
              style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined, size: 20),
            onPressed: () => _sendDeadlineReminder(),
            tooltip: 'Send Deadline Reminder (Push + Email to Unapplied Students)',
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined, size: 20),
            onPressed: () => _exportDriveExcelReport(),
            tooltip: 'Export Excel Report (All Stages & Final Conclusions)',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () {
              ref.invalidate(driveRoundsProvider(widget.drive.id));
              if (_selectedRoundNumber != null) {
                ref.invalidate(roundStudentsProvider((
                  driveId: widget.drive.id,
                  roundNumber: _selectedRoundNumber!,
                )));
              }
            },
            tooltip: 'Refresh Pipeline',
          ),
        ],
      ),
      body: roundsAsync.when(
        data: (rounds) {
          if (rounds.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_empty_rounded, size: 48, color: brandTheme.textMuted),
                  const SizedBox(height: 12),
                  Text('No recruitment rounds configured',
                      style: GoogleFonts.inter(fontSize: 16, color: brandTheme.textMuted)),
                  const SizedBox(height: 8),
                  Text(
                    'Edit this drive to add recruitment rounds.\nStudents will progress through each stage you configure.',
                    style: GoogleFonts.inter(fontSize: 13, color: brandTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Default selected round to Round 1 if not set
          _selectedRoundNumber ??= rounds.first.roundNumber;
          final activeRoundObj = rounds.firstWhere(
            (r) => r.roundNumber == _selectedRoundNumber,
            orElse: () => rounds.first,
          );

          final isLastRound = activeRoundObj.roundNumber == rounds.last.roundNumber;

          return Stack(
            children: [
              Column(
                children: [
                  // ── Top Visual Pipeline Stepper ─────────────────────────
                  _buildPipelineStepper(rounds, theme, brandTheme),

                  const SubtleDivider(height: 1),

                  // ── Search & Filter Controls ────────────────────────────
                  _buildSearchAndFilters(theme, brandTheme, isLastRound: isLastRound),

                  // ── Active Stage Student List ───────────────────────────
                  Expanded(
                    child: _buildStudentStageList(
                      rounds: rounds,
                      activeRound: activeRoundObj,
                      isLastRound: isLastRound,
                      theme: theme,
                      brandTheme: brandTheme,
                    ),
                  ),
                ],
              ),

              // ── Floating Batch Action Bar ─────────────────────────────
              if (_selectedAppIds.isNotEmpty)
                _buildBatchActionBar(activeRoundObj, isLastRound, theme, brandTheme),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: GoogleFonts.inter(color: Colors.red))),
      ),
    ),
  );
  }

  // ---------------------------------------------------------------------------
  // 1. Top Visual Recruitment Pipeline Stepper
  // ---------------------------------------------------------------------------
  Widget _buildPipelineStepper(
    List<DriveRound> rounds,
    ThemeData theme,
    AppBrandTheme brandTheme,
  ) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(rounds.length, (index) {
            final roundNum = rounds[index].roundNumber;
            final roundName = rounds[index].roundName;
            final isSelected = _selectedRoundNumber == roundNum;

            final params = (driveId: widget.drive.id, roundNumber: roundNum);
            final candidateCount = isSelected
                ? (ref.watch(roundStudentsProvider(params)).valueOrNull?.length ?? 0)
                : (ref.read(roundStudentsProvider(params)).valueOrNull?.length ?? 0);

            return Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRoundNumber = roundNum;
                      _selectedAppIds.clear();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? brandTheme.brassPrimary.withValues(alpha: 0.15)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? brandTheme.brassPrimary
                            : brandTheme.cardBorder,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: brandTheme.brassPrimary.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? brandTheme.brassPrimary
                                : brandTheme.cardBorder,
                          ),
                          child: Center(
                            child: Text(
                              '$roundNum',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? brandTheme.onBrass : brandTheme.textMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              roundName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected
                                    ? brandTheme.brassPrimary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '$candidateCount Candidates',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: brandTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < rounds.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: brandTheme.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Search & Filter Bar
  // ---------------------------------------------------------------------------
  // Filter definitions: (value, label, icon, color, description)
  // 'offered' is only shown on the last stage
  static const _allFilters = [
    ('all',      'All',         Icons.people_alt_rounded,      Colors.white,  'Everyone who appeared in this stage'),
    ('pending',  'Awaiting',    Icons.hourglass_top_rounded,   Colors.amber,  'Currently in this stage, result not yet decided'),
    ('cleared',  'Cleared ✓',   Icons.check_circle_rounded,    Colors.green,  'Passed this stage and moved to the next'),
    ('offered',  'Offered 🏆',  Icons.emoji_events_rounded,    Colors.green,  'Received a job offer (final stage only)'),
    ('rejected', 'Rejected',    Icons.cancel_rounded,          Colors.red,    'Did not qualify at this stage'),
  ];

  Widget _buildSearchAndFilters(ThemeData theme, AppBrandTheme brandTheme, {required bool isLastRound}) {
    // Hide 'offered' filter on non-last stages
    final visibleFilters = _allFilters.where((f) => f.$1 != 'offered' || isLastRound).toList();
    // Reset to 'all' if current filter is 'offered' and we switched to non-last stage
    if (_filterStatus == 'offered' && !isLastRound) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _filterStatus = 'all');
      });
    }
    final activeFilter = visibleFilters.firstWhere((f) => f.$1 == _filterStatus, orElse: () => visibleFilters.first);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF141519),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                    cursorColor: brandTheme.brassPrimary,
                    decoration: InputDecoration(
                      hintText: 'Search by name, USN, department or email…',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white38),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: const Icon(Icons.clear_rounded, size: 16, color: Colors.white54),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Filter Label
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              'FILTER BY STAGE RESULT',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Colors.white38,
              ),
            ),
          ),

          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: visibleFilters.map((f) {
                final isActive = _filterStatus == f.$1;
                final chipColor = f.$4 == Colors.white
                    ? brandTheme.brassPrimary
                    : f.$4;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _filterStatus = f.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isActive
                            ? chipColor.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isActive ? chipColor : Colors.white.withValues(alpha: 0.1),
                          width: isActive ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            f.$3,
                            size: 12,
                            color: isActive ? chipColor : Colors.white38,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            f.$2,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                              color: isActive ? chipColor : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Active filter description
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6, bottom: 2),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 11, color: Colors.white24),
                const SizedBox(width: 4),
                Text(
                  activeFilter.$5,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white30, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Active Stage Student List View
  // ---------------------------------------------------------------------------
  Widget _buildStudentStageList({
    required List<DriveRound> rounds,
    required DriveRound activeRound,
    required bool isLastRound,
    required ThemeData theme,
    required AppBrandTheme brandTheme,
  }) {
    final params = (
      driveId: widget.drive.id,
      roundNumber: activeRound.roundNumber,
    );
    final studentsAsync = ref.watch(roundStudentsProvider(params));

    return studentsAsync.when(
      data: (students) {
        // Filter by Search & Status
        final filteredStudents = students.where((s) {
          final student = s['student'] as Map<String, dynamic>? ?? {};
          final name = (student['name'] as String? ?? '').toLowerCase();
          final usn = (student['usn'] as String? ?? '').toLowerCase();
          final email = (student['email'] as String? ?? '').toLowerCase();
          final dept = (student['department'] as String? ?? '').toLowerCase();

          final matchesSearch = _searchQuery.isEmpty ||
              name.contains(_searchQuery) ||
              usn.contains(_searchQuery) ||
              email.contains(_searchQuery) ||
              dept.contains(_searchQuery);

          final status = s['status'] as String? ?? 'applied';          // global app status
          final roundResult = s['round_result'] as String? ?? 'pending'; // per-stage result from application_round_status
          final appCurrentRound = s['current_round'] as int? ?? 1;

          // ── Filter logic — based on per-stage round_result ──────────────────
          // 'pending'  = in this stage, no verdict yet
          // 'cleared'  = passed this stage, promoted to next
          // 'rejected' = eliminated at this stage
          // 'offered'  = selected (last stage)
          bool matchesFilter = true;
          if (_filterStatus == 'pending') {
            matchesFilter = roundResult == 'pending' && status != 'rejected' && status != 'selected';
          } else if (_filterStatus == 'cleared') {
            matchesFilter = roundResult == 'cleared' || appCurrentRound > activeRound.roundNumber;
          } else if (_filterStatus == 'offered') {
            matchesFilter = status == 'selected' || status == 'offered';
          } else if (_filterStatus == 'rejected') {
            matchesFilter = roundResult == 'rejected' || status == 'rejected';
          }

          return matchesSearch && matchesFilter;
        }).toList();

        if (filteredStudents.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.person_off_rounded,
                  size: 44,
                  color: brandTheme.textMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  _searchQuery.isNotEmpty ? 'No candidates match search' : 'No candidates in this stage filter',
                  style: GoogleFonts.fraunces(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try selecting a different filter or search term.',
                  style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(left: 14, right: 14, top: 4, bottom: 90),
          itemCount: filteredStudents.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final app = filteredStudents[index];
            return _buildStudentCard(
              app: app,
              rounds: rounds,
              activeRound: activeRound,
              isLastRound: isLastRound,
              theme: theme,
              brandTheme: brandTheme,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading candidates: $e', style: GoogleFonts.inter(color: Colors.red))),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Student Card Item with Mini-Timeline Stepper
  // ---------------------------------------------------------------------------
  Widget _buildStudentCard({
    required Map<String, dynamic> app,
    required List<DriveRound> rounds,
    required DriveRound activeRound,
    required bool isLastRound,
    required ThemeData theme,
    required AppBrandTheme brandTheme,
  }) {
    final student = app['student'] as Map<String, dynamic>? ?? {};
    final name = student['name'] as String? ?? 'Student';
    final usn = student['usn'] as String? ?? 'N/A';
    final dept = student['department'] as String? ?? 'N/A';
    final cgpa = student['cgpa']?.toString() ?? 'N/A';
    final photoUrl = student['photo_url'] as String?;
    final appId = app['id'] as String;
    final isSelected = _selectedAppIds.contains(appId);
    final status = app['status'] as String? ?? 'applied';
    final roundResult = app['round_result'] as String? ?? 'pending'; // per-stage result
    final appCurrentRound = app['current_round'] as int? ?? 1;

    // Status badge — reflect the per-stage outcome, not the global app status
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'selected' || status == 'offered') {
      statusColor = Colors.green.shade400;
      statusLabel = 'Offered 🏆';
      statusIcon = Icons.emoji_events_rounded;
    } else if (roundResult == 'cleared' || appCurrentRound > activeRound.roundNumber) {
      statusColor = brandTheme.brassPrimary;
      statusLabel = 'Cleared ✓';
      statusIcon = Icons.check_circle_rounded;
    } else if (roundResult == 'rejected' || status == 'rejected') {
      statusColor = Colors.red.shade400;
      statusLabel = 'Rejected';
      statusIcon = Icons.cancel_rounded;
    } else {
      // pending — still in this stage
      statusColor = Colors.amber.shade400;
      statusLabel = 'Awaiting';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return InkWell(
      onTap: () => _showStudentTimelineSheet(
        app: app,
        student: student,
        rounds: rounds,
        activeRound: activeRound,
        isLastRound: isLastRound,
        theme: theme,
        brandTheme: brandTheme,
      ),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? brandTheme.brassPrimary.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? brandTheme.brassPrimary
                : brandTheme.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Checkbox, Avatar, Name & Overall Status
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: brandTheme.brassPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedAppIds.add(appId);
                        } else {
                          _selectedAppIds.remove(appId);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: brandTheme.brassPrimary.withValues(alpha: 0.15),
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: GoogleFonts.fraunces(
                            fontWeight: FontWeight.bold,
                            color: brandTheme.brassPrimary,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        '$usn · $dept · CGPA: $cgpa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Visual Mini-Timeline Stepper for EVERY Candidate
            _buildCandidateMiniTimeline(
              rounds: rounds,
              appCurrentRound: appCurrentRound,
              status: status,
              brandTheme: brandTheme,
            ),

            const SizedBox(height: 10),

            // Bottom Actions & Timestamp Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (app['attended_at'] != null)
                  Row(
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 12, color: brandTheme.brassPrimary),
                      const SizedBox(width: 4),
                      Text(
                        'Scanned at ${_formatTime(app['attended_at'] as String)}',
                        style: GoogleFonts.ibmPlexMono(fontSize: 10, color: brandTheme.brassPrimary),
                      ),
                    ],
                  )
                else
                  Text(
                    'Tap card for complete timeline',
                    style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted, fontStyle: FontStyle.italic),
                  ),
                Row(
                  children: [
                    if (!isLastRound && status != 'rejected')
                      TextButton.icon(
                        onPressed: () => _moveToNextRound([appId]),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        label: Text('Promote', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: brandTheme.brassPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                    else if (isLastRound && status != 'rejected' && status != 'selected')
                      TextButton.icon(
                        onPressed: () => _offerSelected([appId]),
                        icon: const Icon(Icons.emoji_events_rounded, size: 14),
                        label: Text('Offer', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade400,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, size: 18, color: brandTheme.textMuted),
                      onSelected: (act) => _handleAction(act, app),
                      itemBuilder: (_) => [
                        if (!isLastRound && status != 'rejected')
                          PopupMenuItem(
                            value: 'move',
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.amber),
                                const SizedBox(width: 8),
                                Text('Move to Next Round', style: GoogleFonts.inter(fontSize: 12)),
                              ],
                            ),
                          )
                        else if (isLastRound && status != 'selected')
                          PopupMenuItem(
                            value: 'offer',
                            child: Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded, size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                Text('Offer Selection', style: GoogleFonts.inter(fontSize: 12, color: Colors.green)),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'remarks',
                          child: Row(
                            children: [
                              const Icon(Icons.comment_rounded, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text('Add Remarks', style: GoogleFonts.inter(fontSize: 12)),
                            ],
                          ),
                        ),
                        if (status != 'rejected')
                          PopupMenuItem(
                            value: 'reject',
                            child: Row(
                              children: [
                                const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                Text('Reject Candidate', style: GoogleFonts.inter(fontSize: 12, color: Colors.red)),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'absent',
                          child: Row(
                            children: [
                              const Icon(Icons.event_busy_rounded, size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text('Mark Absent', style: GoogleFonts.inter(fontSize: 12, color: Colors.orange)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Candidate Mini-Timeline Progress Bar
  // ---------------------------------------------------------------------------
  Widget _buildCandidateMiniTimeline({
    required List<DriveRound> rounds,
    required int appCurrentRound,
    required String status,
    required AppBrandTheme brandTheme,
  }) {
    final isOffered = status == 'selected' || status == 'offered';
    final isRejected = status == 'rejected';
    final totalStages = rounds.length + 1; // +1 for Offer stage

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(totalStages, (index) {
          final isOfferStage = index == rounds.length;
          final stageNum = index + 1; // 1-based for comparison with appCurrentRound
          final roundName = isOfferStage ? 'Offer' : rounds[index].roundName;

          // ── Compute state ───────────────────────────────────────
          bool isCompleted = false;
          bool isCurrent = false;
          bool isStageRejected = false;

          if (isOfferStage) {
            // Offer node is completed only if student is offered/selected
            isCompleted = isOffered;
          } else if (isOffered) {
            // All rounds completed if offered
            isCompleted = true;
          } else if (isRejected) {
            if (stageNum < appCurrentRound) {
              isCompleted = true;
            } else if (stageNum == appCurrentRound) {
              isStageRejected = true;
            }
          } else {
            if (stageNum < appCurrentRound) {
              isCompleted = true;
            } else if (stageNum == appCurrentRound) {
              isCurrent = true;
            }
          }

          // ── Colors & icon ───────────────────────────────────────
          Color nodeColor;
          Color labelColor;
          Widget nodeIcon;
          Color connectorColor;

          if (isCompleted) {
            nodeColor = const Color(0xFF22C55E); // vivid green
            labelColor = const Color(0xFF4ADE80);
            nodeIcon = const Icon(Icons.check_rounded, size: 12, color: Colors.white);
            connectorColor = const Color(0xFF22C55E);
          } else if (isStageRejected) {
            nodeColor = const Color(0xFFEF4444);
            labelColor = const Color(0xFFFCA5A5);
            nodeIcon = const Icon(Icons.close_rounded, size: 12, color: Colors.white);
            connectorColor = Colors.grey.shade800;
          } else if (isCurrent) {
            nodeColor = brandTheme.brassPrimary;
            labelColor = brandTheme.brassPrimary;
            nodeIcon = Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: brandTheme.onBrass,
                shape: BoxShape.circle,
              ),
            );
            connectorColor = Colors.grey.shade800;
          } else {
            // pending
            nodeColor = Colors.grey.shade800;
            labelColor = Colors.grey.shade600;
            nodeIcon = const SizedBox.shrink();
            connectorColor = Colors.grey.shade800;
          }

          final isLast = index == totalStages - 1;
          const nodeSize = 24.0;
          const connectorH = 2.0;
          const connectorW = 24.0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stage node + label
              SizedBox(
                width: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circle node
                    Container(
                      width: nodeSize,
                      height: nodeSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: nodeColor,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: brandTheme.brassPrimary.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : isCompleted
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                        border: isCurrent
                            ? Border.all(color: brandTheme.brassPrimary, width: 2)
                            : null,
                      ),
                      child: Center(child: nodeIcon),
                    ),
                    const SizedBox(height: 4),
                    // Round name below node
                    Text(
                      roundName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: isCurrent || isCompleted ? FontWeight.w700 : FontWeight.w400,
                        color: labelColor,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Connector line (skip on last)
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(top: nodeSize / 2 - connectorH / 2),
                  child: Container(
                    width: connectorW,
                    height: connectorH,
                    decoration: BoxDecoration(
                      color: connectorColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Complete Student Recruitment Details Bottom Sheet
  // ---------------------------------------------------------------------------
  void _showStudentTimelineSheet({
    required Map<String, dynamic> app,
    required Map<String, dynamic> student,
    required List<DriveRound> rounds,
    required DriveRound activeRound,
    required bool isLastRound,
    required ThemeData theme,
    required AppBrandTheme brandTheme,
  }) {
    final appId = app['id'] as String;
    final name = student['name'] as String? ?? 'Student';
    final usn = student['usn'] as String? ?? 'N/A';
    final email = student['email'] as String? ?? 'N/A';
    final dept = student['department'] as String? ?? 'N/A';
    final cgpa = student['cgpa']?.toString() ?? 'N/A';
    final phone = student['phone'] as String? ?? 'N/A';
    final photoUrl = student['photo_url'] as String?;
    final appCurrentRound = app['current_round'] as int? ?? 1;
    final status = app['status'] as String? ?? 'applied';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).padding.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header Profile Card
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: brandTheme.brassPrimary.withValues(alpha: 0.15),
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: GoogleFonts.fraunces(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: brandTheme.brassPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('$usn · $dept · $email', style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
                      Text('CGPA: $cgpa · Phone: $phone', style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const SubtleDivider(height: 1),
            const SizedBox(height: 12),

            Text(
              'Recruitment Stage Progression',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: brandTheme.brassPrimary),
            ),
            const SizedBox(height: 10),

            // Full Vertical Recruitment Timeline
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final progressAsync = ref.watch(studentRoundProgressProvider(appId));

                  return progressAsync.when(
                    data: (progressList) {
                      final progressMap = <String, Map<String, dynamic>>{};
                      for (final p in progressList) {
                        if (p['round_id'] != null) {
                          progressMap[p['round_id'] as String] = p;
                        }
                      }

                      return ListView.builder(
                        itemCount: rounds.length,
                        itemBuilder: (context, index) {
                          final round = rounds[index];
                          final roundNum = round.roundNumber;
                          final roundProgress = progressMap[round.id];
                          final isSelected = status == 'selected' || status == 'offered';
                          final isRejected = status == 'rejected';

                          bool isCompleted = false;
                          bool isCurrent = false;
                          bool isStageRejected = false;

                          if (isSelected) {
                            isCompleted = true;
                          } else if (isRejected) {
                            if (roundNum < appCurrentRound) {
                              isCompleted = true;
                            } else if (roundNum == appCurrentRound) {
                              isStageRejected = true;
                            }
                          } else {
                            if (roundNum < appCurrentRound) {
                              isCompleted = true;
                            } else if (roundNum == appCurrentRound) {
                              isCurrent = true;
                            }
                          }

                          final resultStr = roundProgress?['result'] as String? ?? (isCompleted ? 'cleared' : (isStageRejected ? 'rejected' : 'pending'));
                          final remarks = roundProgress?['remarks'] as String?;

                          Color stageColor = Colors.grey.shade700;
                          String stageStatusText = 'Pending Stage';

                          if (resultStr == 'cleared' || isCompleted) {
                            stageColor = Colors.green.shade500;
                            stageStatusText = 'Completed ✓';
                          } else if (resultStr == 'rejected' || isStageRejected) {
                            stageColor = Colors.red.shade500;
                            stageStatusText = 'Rejected';
                          } else if (isCurrent) {
                            stageColor = brandTheme.brassPrimary;
                            stageStatusText = 'Current Stage';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141519),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: stageColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: stageColor.withValues(alpha: 0.2),
                                  child: Text(
                                    '$roundNum',
                                    style: GoogleFonts.ibmPlexMono(
                                      fontWeight: FontWeight.bold,
                                      color: stageColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            round.roundName,
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: stageColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                            child: Text(
                                              stageStatusText,
                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: stageColor),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (round.scheduledDate != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Scheduled: ${round.scheduledDate!.day}/${round.scheduledDate!.month}/${round.scheduledDate!.year}',
                                          style: GoogleFonts.ibmPlexMono(fontSize: 10, color: brandTheme.textMuted),
                                        ),
                                      ],
                                      if (remarks != null && remarks.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.04),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.comment_outlined, size: 12, color: brandTheme.brassPrimary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Remarks: $remarks',
                                                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Bottom Action Bar inside Modal
            Row(
              children: [
                if (!isLastRound && status != 'rejected')
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _moveToNextRound([appId]);
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text('Promote to Round ${activeRound.roundNumber + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(backgroundColor: brandTheme.brassPrimary, foregroundColor: brandTheme.onBrass),
                    ),
                  )
                else if (isLastRound && status != 'rejected' && status != 'selected')
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _offerSelected([appId]);
                      },
                      icon: const Icon(Icons.emoji_events_rounded, size: 16),
                      label: const Text('Offer Selection', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                    ),
                  ),
                if (status != 'rejected') ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _rejectStudents([appId]);
                    },
                    icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                    label: const Text('Reject', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade300)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Floating Batch Action Bar
  // ---------------------------------------------------------------------------
  Widget _buildBatchActionBar(
    DriveRound activeRound,
    bool isLastRound,
    ThemeData theme,
    AppBrandTheme brandTheme,
  ) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: brandTheme.brassPrimary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: brandTheme.brassPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${_selectedAppIds.length} Selected',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: brandTheme.brassPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (!isLastRound)
                      InkWell(
                        onTap: _bulkMoveNext,
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: brandTheme.brassPrimary,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_forward_rounded, size: 14, color: brandTheme.onBrass),
                              const SizedBox(width: 4),
                              Text('Promote Selected', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: brandTheme.onBrass)),
                            ],
                          ),
                        ),
                      )
                    else
                      InkWell(
                        onTap: () => _offerSelected(_selectedAppIds.toList()),
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.emoji_events_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text('Offer Selected', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _bulkReject,
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('Reject Selected', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _bulkAbsent,
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade700,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_busy_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('Mark Absent', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Format ISO timestamp → "5:18 PM"
  // ---------------------------------------------------------------------------
  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    } catch (_) {
      return isoString;
    }
  }

  // ---------------------------------------------------------------------------
  // Action Handlers
  // ---------------------------------------------------------------------------
  void _handleAction(String action, Map<String, dynamic> app) {
    switch (action) {
      case 'move':
        _moveToNextRound([app['id']]);
        break;
      case 'offer':
        _offerSelected([app['id']]);
        break;
      case 'reject':
        _rejectStudents([app['id']]);
        break;
      case 'absent':
        _markAbsent([app['id']]);
        break;
      case 'remarks':
        _showRemarksDialog(app['id']);
        break;
    }
  }

  Future<void> _bulkMoveNext() async {
    await _moveToNextRound(_selectedAppIds.toList());
    setState(() => _selectedAppIds.clear());
  }

  Future<void> _bulkReject() async {
    await _rejectStudents(_selectedAppIds.toList());
    setState(() => _selectedAppIds.clear());
  }

  Future<void> _bulkAbsent() async {
    await _markAbsent(_selectedAppIds.toList());
    setState(() => _selectedAppIds.clear());
  }

  Future<void> _moveToNextRound(List<String> appIds) async {
    final repo = ref.read(tpoRepositoryProvider);
    final user = Supabase.instance.client.auth.currentUser;
    await repo.moveStudentsToNextRound(
      driveId: widget.drive.id,
      currentRoundNumber: _selectedRoundNumber ?? 1,
      applicationIds: appIds,
      performedBy: user?.id ?? '',
    );
    if (!mounted) return;
    ref.invalidate(roundStudentsProvider((driveId: widget.drive.id, roundNumber: _selectedRoundNumber ?? 1)));
    ref.invalidate(roundStudentsProvider((driveId: widget.drive.id, roundNumber: (_selectedRoundNumber ?? 1) + 1)));

    // Send notifications & emails
    try {
      final emailService = ref.read(emailNotificationServiceProvider);
      for (final appId in appIds) {
        final appData = await Supabase.instance.client
            .from('applications')
            .select('student_id, current_round, student:profiles(email, name)')
            .eq('id', appId)
            .maybeSingle();
        if (appData != null && (appData['current_round'] as int? ?? 0) == (_selectedRoundNumber ?? 1) + 1) {
          final studentId = appData['student_id'] as String?;
          final student = appData['student'] as Map<String, dynamic>?;
          final email = student?['email'] as String?;
          final name = (student?['name'] as String?) ?? 'Student';

          if (email != null && email.contains('@')) {
            // Look up real round names from cached data
            final rounds = ref.read(driveRoundsProvider(widget.drive.id)).valueOrNull ?? [];
            final currentRound = rounds.firstWhere(
              (r) => r.roundNumber == (_selectedRoundNumber ?? 1),
              orElse: () => rounds.isNotEmpty ? rounds.first : throw Exception('no round'),
            );
            final nextRoundIndex = rounds.indexWhere((r) => r.roundNumber == (_selectedRoundNumber ?? 1)) + 1;
            final nextRoundName = nextRoundIndex < rounds.length ? rounds[nextRoundIndex].roundName : 'Final Selection';

            emailService.sendRoundQualifiedEmail(
              recipientEmail: email,
              studentName: name,
              companyName: widget.drive.companyName,
              qualifiedRound: currentRound.roundName,
              nextRoundName: nextRoundName,
            );
          }

          if (studentId != null && studentId.isNotEmpty) {
            repo.sendNotification(
              userId: studentId,
              title: 'Congratulations! Stage Cleared',
              body: 'You cleared Stage ${_selectedRoundNumber ?? 1} for ${widget.drive.companyName}!',
              type: 'round_clear',
              driveId: widget.drive.id,
              applicationId: appId,
            );
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ ${appIds.length} candidate(s) promoted to next stage!')),
      );
    }
  }

  Future<void> _offerSelected(List<String> appIds) async {
    final repo = ref.read(tpoRepositoryProvider);
    final user = Supabase.instance.client.auth.currentUser;
    await repo.offerStudents(
      driveId: widget.drive.id,
      currentRoundNumber: _selectedRoundNumber ?? 1,
      applicationIds: appIds,
      performedBy: user?.id ?? '',
    );
    if (!mounted) return;
    setState(() {
      _selectedAppIds.removeAll(appIds);
    });
    ref.invalidate(roundStudentsProvider((driveId: widget.drive.id, roundNumber: _selectedRoundNumber ?? 1)));
    ref.invalidate(tpoOffersCountProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🏆 ${appIds.length} candidate(s) offered selection!'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<void> _rejectStudents(List<String> appIds) async {
    final repo = ref.read(tpoRepositoryProvider);
    final user = Supabase.instance.client.auth.currentUser;
    await repo.rejectStudents(
      driveId: widget.drive.id,
      currentRoundNumber: _selectedRoundNumber ?? 1,
      applicationIds: appIds,
      performedBy: user?.id ?? '',
    );
    ref.invalidate(roundStudentsProvider((driveId: widget.drive.id, roundNumber: _selectedRoundNumber ?? 1)));

    try {
      final emailService = ref.read(emailNotificationServiceProvider);
      for (final appId in appIds) {
        final appData = await Supabase.instance.client
            .from('applications')
            .select('student_id, student:profiles(email, name)')
            .eq('id', appId)
            .maybeSingle();
        if (appData != null && appData['student'] != null) {
          final student = appData['student'] as Map<String, dynamic>;
          final email = student['email'] as String?;
          final name = (student['name'] as String?) ?? 'Student';
          if (email != null && email.contains('@')) {
            emailService.sendRoundRejectedEmail(
              recipientEmail: email,
              studentName: name,
              companyName: widget.drive.companyName,
              rejectedRound: 'Stage ${_selectedRoundNumber ?? 1}',
            );
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${appIds.length} candidate(s) rejected')),
      );
    }
  }

  Future<void> _markAbsent(List<String> appIds) async {
    final repo = ref.read(tpoRepositoryProvider);
    final user = Supabase.instance.client.auth.currentUser;
    await repo.markStudentsAbsent(
      driveId: widget.drive.id,
      currentRoundNumber: _selectedRoundNumber ?? 1,
      applicationIds: appIds,
      performedBy: user?.id ?? '',
    );
    ref.invalidate(roundStudentsProvider((driveId: widget.drive.id, roundNumber: _selectedRoundNumber ?? 1)));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚪ ${appIds.length} candidate(s) marked absent')),
      );
    }
  }

  void _showRemarksDialog(String applicationId) {
    final remarksController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Remarks', style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: remarksController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Enter remarks...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final repo = ref.read(tpoRepositoryProvider);
              final user = Supabase.instance.client.auth.currentUser;
              final roundData = await ref.read(tpoRepositoryProvider).getDriveRounds(widget.drive.id);
              final currentRound = roundData.firstWhere((r) => r.roundNumber == (_selectedRoundNumber ?? 1));
              await repo.addRoundRemarks(
                applicationId: applicationId,
                roundId: currentRound.id,
                remarks: remarksController.text.trim(),
                performedBy: user?.id ?? '',
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendDeadlineReminder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Send Deadline Reminder', style: GoogleFonts.fraunces(color: Colors.white, fontSize: 18)),
        content: Text(
          'This will send instant Push Notifications and Emails to all eligible students who have not yet applied for ${widget.drive.companyName} (${widget.drive.roleTitle}).',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text('Send Push & Email', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = ref.read(tpoRepositoryProvider);
    final user = Supabase.instance.client.auth.currentUser;
    final count = await repo.sendDriveDeadlineReminder(
      driveId: widget.drive.id,
      performedBy: user?.id ?? 'TPO Admin',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Dispatched deadline push notifications to $count eligible students.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  Future<void> _exportDriveExcelReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating Comprehensive Drive Excel Report...')),
    );

    try {
      final supabase = Supabase.instance.client;

      // 1. Fetch rounds for this drive
      final roundsData = await supabase
          .from('drive_rounds')
          .select()
          .eq('drive_id', widget.drive.id)
          .order('round_number', ascending: true);

      final rounds = (roundsData as List).map((e) => DriveRound.fromMap(e)).toList();

      // 2. Fetch all applications with student profiles
      final appsData = await supabase
          .from('applications')
          .select('*, student:profiles(*)')
          .eq('drive_id', widget.drive.id);

      final applications = (appsData as List);

      // 3. Fetch round status / history
      final appIds = applications.map((a) => a['id'] as String).toList();
      List evaluations = [];
      if (appIds.isNotEmpty) {
        try {
          final statusData = await supabase
              .from('application_round_status')
              .select('application_id, round_id, result, attended')
              .filter('application_id', 'in', appIds);

          evaluations = (statusData as List);
        } catch (_) {}
      }

      // 4. Fetch Drive Attendance (QR Scans)
      final driveAttendanceMap = <String, Map<String, dynamic>>{};
      try {
        final attData = await supabase
            .from('drive_attendance')
            .select('student_id, scanned_at, status')
            .eq('drive_id', widget.drive.id);
        for (final a in (attData as List)) {
          if (a is Map<String, dynamic> && a['student_id'] != null) {
            driveAttendanceMap[a['student_id'] as String] = a;
          }
        }
      } catch (_) {}

      // 5. Create Excel Workbook
      final excel = excel_pkg.Excel.createExcel();
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Helper for scan time formatting
      String formatScanTime(dynamic iso) {
        if (iso == null || iso.toString().isEmpty) return '';
        try {
          final dt = DateTime.parse(iso.toString()).toLocal();
          final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
          final m = dt.minute.toString().padLeft(2, '0');
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          return ' ($h:$m $ampm)';
        } catch (_) {
          return '';
        }
      }

      // Sheet 1: Final Summary & Conclusions
      final summarySheet = excel['Final Conclusion'];
      excel.setDefaultSheet('Final Conclusion');

      summarySheet.appendRow([
        excel_pkg.TextCellValue('Drive Summary & Final Conclusion Report'),
      ]);
      summarySheet.appendRow([
        excel_pkg.TextCellValue('Company:'),
        excel_pkg.TextCellValue(widget.drive.companyName),
        excel_pkg.TextCellValue('Role:'),
        excel_pkg.TextCellValue(widget.drive.roleTitle),
      ]);
      summarySheet.appendRow([
        excel_pkg.TextCellValue('CTC / Stipend:'),
        excel_pkg.TextCellValue(widget.drive.ctcOrStipend),
        excel_pkg.TextCellValue('Export Date:'),
        excel_pkg.TextCellValue(DateTime.now().toString().split('.')[0]),
      ]);
      summarySheet.appendRow([]); // Empty spacer row

      // Headers for Summary (including QR Scan & per-round attendance)
      final summaryHeaders = <excel_pkg.CellValue>[
        excel_pkg.TextCellValue('USN / Roll No'),
        excel_pkg.TextCellValue('Student Name'),
        excel_pkg.TextCellValue('Department'),
        excel_pkg.TextCellValue('Email'),
        excel_pkg.TextCellValue('Phone'),
        excel_pkg.TextCellValue('CGPA'),
        excel_pkg.TextCellValue('Drive QR Scan Attendance'),
      ];

      for (final r in rounds) {
        summaryHeaders.add(excel_pkg.TextCellValue('Stage ${r.roundNumber}: ${r.roundName} (Attendance)'));
        summaryHeaders.add(excel_pkg.TextCellValue('Stage ${r.roundNumber}: ${r.roundName} (Result)'));
      }

      summaryHeaders.addAll([
        excel_pkg.TextCellValue('Current Stage'),
        excel_pkg.TextCellValue('Final Status / Conclusion'),
        excel_pkg.TextCellValue('Offer Status'),
      ]);

      summarySheet.appendRow(summaryHeaders);

      int offeredCount = 0;
      int rejectedCount = 0;
      int inProgressCount = 0;
      int qrAttendedCount = 0;

      for (final app in applications) {
        final appId = app['id'] as String;
        final studentId = app['student_id'] as String? ?? '';
        final student = app['student'] as Map<String, dynamic>? ?? {};
        final status = app['status'] as String? ?? 'applied';
        final currentRoundNum = app['current_round'] as int? ?? 1;

        // Drive QR scan check
        final qrRecord = driveAttendanceMap[studentId];
        String qrScanText = 'Not Scanned (Absent)';
        if (qrRecord != null && qrRecord['status'] != 'absent') {
          qrAttendedCount++;
          qrScanText = 'Present${formatScanTime(qrRecord['scanned_at'])}';
        }

        String conclusion = 'In Selection Process';
        if (status == 'selected' || status == 'offered') {
          conclusion = 'FINAL SELECTED / OFFERED';
          offeredCount++;
        } else if (status == 'rejected') {
          conclusion = 'REJECTED (Stage $currentRoundNum)';
          rejectedCount++;
        } else {
          inProgressCount++;
        }

        final rowValues = <excel_pkg.CellValue>[
          excel_pkg.TextCellValue((student['usn'] as String?) ?? 'N/A'),
          excel_pkg.TextCellValue((student['name'] as String?) ?? 'Student'),
          excel_pkg.TextCellValue((student['department'] as String?) ?? 'N/A'),
          excel_pkg.TextCellValue((student['email'] as String?) ?? ''),
          excel_pkg.TextCellValue((student['phone'] as String?) ?? 'N/A'),
          excel_pkg.TextCellValue(student['cgpa']?.toString() ?? 'N/A'),
          excel_pkg.TextCellValue(qrScanText),
        ];

        // Append every round's attendance and result
        for (final r in rounds) {
          final roundStat = evaluations.firstWhere(
            (e) => e['application_id'] == appId && e['round_id'] == r.id,
            orElse: () => <String, dynamic>{},
          );

          final roundResult = roundStat['result'] as String?;
          final attendedVal = roundStat['attended'];

          String roundAttendance = 'N/A';
          if (attendedVal == true) {
            roundAttendance = 'Present';
          } else if (attendedVal == false) {
            roundAttendance = 'Absent';
          } else if (currentRoundNum >= r.roundNumber || status == 'selected' || status == 'offered') {
            roundAttendance = qrRecord != null ? 'Present' : 'Pending';
          }

          String roundResultText = 'N/A';
          if (roundResult != null) {
            roundResultText = roundResult.toUpperCase();
          } else if (currentRoundNum > r.roundNumber || status == 'selected' || status == 'offered') {
            roundResultText = 'CLEARED';
          } else if (currentRoundNum == r.roundNumber) {
            roundResultText = status == 'rejected' ? 'REJECTED' : 'IN PROGRESS';
          }

          rowValues.add(excel_pkg.TextCellValue(roundAttendance));
          rowValues.add(excel_pkg.TextCellValue(roundResultText));
        }

        rowValues.addAll([
          excel_pkg.TextCellValue('Stage $currentRoundNum'),
          excel_pkg.TextCellValue(conclusion),
          excel_pkg.TextCellValue((status == 'selected' ? 'OFFERED' : status).toUpperCase()),
        ]);

        summarySheet.appendRow(rowValues);
      }

      summarySheet.appendRow([]);
      summarySheet.appendRow([excel_pkg.TextCellValue('--- OVERALL DRIVE METRICS ---')]);
      summarySheet.appendRow([excel_pkg.TextCellValue('Total Applicants'), excel_pkg.IntCellValue(applications.length)]);
      summarySheet.appendRow([excel_pkg.TextCellValue('Total Drive QR Check-ins'), excel_pkg.IntCellValue(qrAttendedCount)]);
      summarySheet.appendRow([excel_pkg.TextCellValue('Total Final Offers'), excel_pkg.IntCellValue(offeredCount)]);
      summarySheet.appendRow([excel_pkg.TextCellValue('Total Rejected'), excel_pkg.IntCellValue(rejectedCount)]);
      summarySheet.appendRow([excel_pkg.TextCellValue('In Progress'), excel_pkg.IntCellValue(inProgressCount)]);

      // Sheet 2 to N: Individual Stage/Round Breakdown
      for (final round in rounds) {
        final sheetName = 'Stage ${round.roundNumber} - ${round.roundName.replaceAll(RegExp(r'[\[\]\*\/\\\?\:]'), '_')}';
        final roundSheet = excel[sheetName];

        roundSheet.appendRow([
          excel_pkg.TextCellValue('Stage ${round.roundNumber}: ${round.roundName}'),
        ]);
        roundSheet.appendRow([]);

        roundSheet.appendRow([
          excel_pkg.TextCellValue('USN'),
          excel_pkg.TextCellValue('Student Name'),
          excel_pkg.TextCellValue('Department'),
          excel_pkg.TextCellValue('Drive QR Scan'),
          excel_pkg.TextCellValue('Stage Attendance'),
          excel_pkg.TextCellValue('Stage Result'),
        ]);

        for (final app in applications) {
          final appId = app['id'] as String;
          final studentId = app['student_id'] as String? ?? '';
          final student = app['student'] as Map<String, dynamic>? ?? {};
          final currentRoundNum = app['current_round'] as int? ?? 1;
          final appStatus = app['status'] as String? ?? 'applied';

          final qrRecord = driveAttendanceMap[studentId];
          String qrScanText = 'Not Scanned';
          if (qrRecord != null && qrRecord['status'] != 'absent') {
            qrScanText = 'Present${formatScanTime(qrRecord['scanned_at'])}';
          }

          final roundStat = evaluations.firstWhere(
            (e) => e['application_id'] == appId && e['round_id'] == round.id,
            orElse: () => <String, dynamic>{},
          );

          final roundResult = roundStat['result'] as String?;
          final attendedVal = roundStat['attended'];

          String stageAttendance = 'N/A';
          if (attendedVal == true) {
            stageAttendance = 'Present';
          } else if (attendedVal == false) {
            stageAttendance = 'Absent';
          } else if (currentRoundNum >= round.roundNumber || appStatus == 'selected' || appStatus == 'offered') {
            stageAttendance = qrRecord != null ? 'Present' : 'Pending';
          }

          String stageStatus = 'N/A';
          if (roundResult != null) {
            stageStatus = roundResult.toUpperCase();
          } else if (currentRoundNum > round.roundNumber || appStatus == 'selected' || appStatus == 'offered') {
            stageStatus = 'CLEARED';
          } else if (currentRoundNum == round.roundNumber) {
            stageStatus = appStatus == 'rejected' ? 'REJECTED' : 'IN PROGRESS';
          }

          roundSheet.appendRow([
            excel_pkg.TextCellValue((student['usn'] as String?) ?? 'N/A'),
            excel_pkg.TextCellValue((student['name'] as String?) ?? 'Student'),
            excel_pkg.TextCellValue((student['department'] as String?) ?? 'N/A'),
            excel_pkg.TextCellValue(qrScanText),
            excel_pkg.TextCellValue(stageAttendance),
            excel_pkg.TextCellValue(stageStatus),
          ]);
        }
      }

      // Save & Share File
      final fileBytes = excel.save();
      if (fileBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final fileName = '${widget.drive.companyName}_Drive_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(fileBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Drive Stage & Final Conclusion Report for ${widget.drive.companyName}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate Excel report: $e')),
        );
      }
    }
  }
}
