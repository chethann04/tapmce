import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/audit_log_entry.dart';
import '../../domain/repositories/audit_log_repository.dart';

final auditLogsProvider = FutureProvider.autoDispose<List<AuditLogEntry>>((ref) async {
  final repo = ref.watch(auditLogRepositoryProvider);
  final result = await repo.getAuditLogs();
  
  if (result.failure != null) {
    throw Exception(result.failure!.message);
  }
  
  return result.data ?? [];
});
