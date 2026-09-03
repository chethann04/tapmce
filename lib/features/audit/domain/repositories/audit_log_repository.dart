import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../entities/audit_log_entry.dart';
import '../../data/repositories/audit_log_repository_impl.dart';

abstract class AuditLogRepository {
  Future<({List<AuditLogEntry>? data, Failure? failure})> getAuditLogs();
  
  Future<({void data, Failure? failure})> logAction({
    required AuditAction action,
    String? targetTable,
    String? targetId,
    required String description,
  });
}

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepositoryImpl();
});
