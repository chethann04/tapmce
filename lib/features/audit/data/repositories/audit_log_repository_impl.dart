import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/repositories/audit_log_repository.dart';

class AuditLogRepositoryImpl implements AuditLogRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<({List<AuditLogEntry>? data, Failure? failure})> getAuditLogs() async {
    try {
      final response = await _supabase
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> logsJson = response as List<dynamic>;
      
      // Extract unique actor_ids
      final actorIds = logsJson
          .map((e) => e['actor_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      // Fetch profiles
      Map<String, dynamic> profilesMap = {};
      if (actorIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('id, name, role')
            .inFilter('id', actorIds);
            
        for (var profile in profilesResponse as List<dynamic>) {
          profilesMap[profile['id']] = profile;
        }
      }

      final List<AuditLogEntry> logs = [];
      for (final json in logsJson) {
        try {
          final actorId = json['actor_id'] as String?;
          if (actorId != null && profilesMap.containsKey(actorId)) {
            json['profiles'] = profilesMap[actorId];
          }
          logs.add(AuditLogEntry.fromJson(json as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Skipping malformed audit log entry: $e');
        }
      }

      return (data: logs, failure: null);
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      return (data: null, failure: Failure.server(message: 'Failed to fetch audit logs: $e'));
    }
  }

  @override
  Future<({void data, Failure? failure})> logAction({
    required AuditAction action,
    String? targetTable,
    String? targetId,
    required String description,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return (data: null, failure: Failure.server(message: 'Cannot log action: User not authenticated'));
      }

      await _supabase.from('audit_logs').insert({
        'actor_id': userId,
        'action': formatAuditAction(action),
        'table_name': targetTable ?? 'profiles',
        'target_table': targetTable ?? 'profiles',
        'target_id': targetId,
        'details': {'description': description},
      });

      return (data: null, failure: null);
    } catch (e) {
      debugPrint('Error saving audit log: $e');
      return (data: null, failure: Failure.server(message: 'Failed to save audit log: $e'));
    }
  }
}
