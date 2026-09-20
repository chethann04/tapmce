import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Full application data with rounds and round progress for the timeline.
class ApplicationTimelineData {
  final String applicationId;
  final String driveId;
  final String status;
  final int currentRound;
  final DateTime appliedAt;
  final String companyName;
  final String roleTitle;
  final String ctcDisplay;
  final DateTime applicationDeadline;
  final String driveStatus;
  final String resumeUrl;
  final List<Map<String, dynamic>> rounds;
  final List<Map<String, dynamic>> roundProgress;

  ApplicationTimelineData({
    required this.applicationId,
    required this.driveId,
    required this.status,
    required this.currentRound,
    required this.appliedAt,
    required this.companyName,
    required this.roleTitle,
    required this.ctcDisplay,
    required this.applicationDeadline,
    required this.driveStatus,
    required this.resumeUrl,
    required this.rounds,
    required this.roundProgress,
  });

  int get totalRounds => rounds.length;
  int get completedRounds => roundProgress.where((r) =>
      r['result'] == 'cleared' || r['result'] == 'selected' || r['result'] == 'passed').length;
  double get progressPercent => totalRounds > 0 ? completedRounds / totalRounds : 0;

  /// Get the round_id that the student is currently on.
  String? get currentRoundId {
    if (currentRound <= 0 || currentRound > rounds.length) return null;
    return rounds[currentRound - 1]['id'] as String?;
  }

  /// Get progress for a specific round.
  Map<String, dynamic>? progressForRound(String roundId) {
    try {
      return roundProgress.firstWhere((p) => p['round_id'] == roundId);
    } catch (_) {
      return null;
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// TIMELINE NOTIFIER — Real-time backed student timeline
// ──────────────────────────────────────────────────────────────────────────────

class StudentTimelineNotifier extends AsyncNotifier<List<ApplicationTimelineData>> {
  RealtimeChannel? _channel;

  @override
  Future<List<ApplicationTimelineData>> build() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    // Subscribe to real-time updates on the applications table for this student.
    // When TPO changes current_round or status, this fires and refreshes the timeline.
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('student_timeline_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'applications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: user.id,
          ),
          callback: (_) {
            // Re-fetch when any application row is inserted, updated, or deleted
            ref.invalidateSelf();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'application_round_status',
          callback: (_) {
            // Re-fetch when round_status changes
            ref.invalidateSelf();
          },
        )
        .subscribe();

    ref.onDispose(() {
      _channel?.unsubscribe();
      _channel = null;
    });

    return _fetchTimeline(user.id);
  }

  /// Public method to force a manual refresh (e.g., pull-to-refresh).
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  static Future<List<ApplicationTimelineData>> _fetchTimeline(String userId) async {
    // Execute independent parallel queries for instantaneous data fetching
    List<Map<String, dynamic>> apps = [];
    Map<String, dynamic>? profileResponse;

    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('applications')
            .select('''
              id, drive_id, status, current_round, applied_at, updated_at,
              drive:drives(
                id, role, package_lpa,
                end_date,
                company:companies(name),
                drive_rounds(id, round_number, round_name, round_date, round_time, venue_or_link)
              )
            ''')
            .eq('student_id', userId)
            .order('applied_at', ascending: false),
        Supabase.instance.client
            .from('profiles')
            .select('resume_url')
            .eq('id', userId)
            .maybeSingle(),
      ]);

      apps = (results[0] as List).cast<Map<String, dynamic>>();
      profileResponse = results[1] as Map<String, dynamic>?;
    } catch (e) {
      // Fallback: Query applications without nested join if foreign key cache is refreshing
      try {
        final rawApps = await Supabase.instance.client
            .from('applications')
            .select()
            .eq('student_id', userId)
            .order('applied_at', ascending: false);
        apps = (rawApps as List).cast<Map<String, dynamic>>();
      } catch (_) {
        return [];
      }
    }

    final resumeUrl = profileResponse?['resume_url'] as String? ?? '';

    if (apps.isEmpty) return [];

    // Fetch round progress for all applications in a single batch query
    final appIds = apps.map((a) => a['id'] as String).toList();
    List<Map<String, dynamic>> allProgress = [];
    try {
      final progressResponse = await Supabase.instance.client
          .from('application_round_status')
          .select('*, round:drive_rounds(round_number, round_name)')
          .inFilter('application_id', appIds);
      allProgress = (progressResponse as List).cast<Map<String, dynamic>>();
    } catch (_) {}

    // Map into ApplicationTimelineData
    return apps.map((app) {
      final drive = app['drive'] as Map<String, dynamic>? ?? {};
      final company = drive['company'] as Map<String, dynamic>? ?? {};
      final rounds = <Map<String, dynamic>>[];
      final rawRounds = (drive['drive_rounds'] as List?) ?? [];
      for (final r in rawRounds) {
        if (r is Map<String, dynamic>) {
          rounds.add(r);
        } else if (r is Map) {
          rounds.add(Map<String, dynamic>.from(r));
        } else {
          try {
            rounds.add({
              'id': (r as dynamic).id,
              'round_number': (r as dynamic).roundNumber ?? 1,
              'round_name': (r as dynamic).roundName ?? '',
              
              
              'round_date': (r as dynamic).roundDate,
              'round_time': (r as dynamic).roundTime,
              'venue_or_link': (r as dynamic).venueOrLink,
            });
          } catch (_) {}
        }
      }

      // Sort rounds by round_number
      rounds.sort((a, b) => (a['round_number'] as int? ?? 0).compareTo(b['round_number'] as int? ?? 0));

      // Get progress for this application
      final appProgress = allProgress.where((p) => p['application_id'] == app['id']).toList();

      String ctcDisplay = 'Disclosed on selection';
      if (drive['ctc_or_stipend'] != null) {
        ctcDisplay = drive['ctc_or_stipend'].toString();
      } else if (drive['package_lpa'] != null) {
        ctcDisplay = '₹${drive['package_lpa']} LPA';
      }

      final deadlineStr = drive['end_date'] as String? ?? drive['application_deadline'] as String? ?? '';
      final deadline = DateTime.tryParse(deadlineStr) ?? DateTime.now().add(const Duration(days: 14));

      final appResumeUrl = app['resume_version_url'] as String?;
      final finalResumeUrl = (appResumeUrl != null && appResumeUrl.isNotEmpty) ? appResumeUrl : resumeUrl;

      return ApplicationTimelineData(
        applicationId: app['id'] as String,
        driveId: app['drive_id'] as String,
        status: app['status'] as String? ?? 'applied',
        currentRound: app['current_round'] as int? ?? 1,
        appliedAt: DateTime.tryParse(app['applied_at'] as String? ?? '') ?? DateTime.now(),
        companyName: company['name'] as String? ?? 'Company',
        roleTitle: drive['role_title'] as String? ?? drive['role'] as String? ?? 'Role',
        ctcDisplay: ctcDisplay,
        applicationDeadline: deadline,
        driveStatus: drive['drive_status'] as String? ?? drive['status'] as String? ?? 'upcoming',
        resumeUrl: finalResumeUrl,
        rounds: rounds,
        roundProgress: appProgress,
      );
    }).toList();
  }
}

/// Real-time backed provider for student application timeline.
/// Instantly updates when TPO promotes student to next round.
final studentTimelineProvider =
    AsyncNotifierProvider<StudentTimelineNotifier, List<ApplicationTimelineData>>(
  StudentTimelineNotifier.new,
);

/// Latest notifications for the student.
final studentNotificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final response = await Supabase.instance.client
      .from('notifications')
      .select('id, title, body, type, read, created_at, drive_id, application_id')
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(20);

  return (response as List).cast<Map<String, dynamic>>();
});





