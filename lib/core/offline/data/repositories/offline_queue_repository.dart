import 'dart:convert';
import 'package:drift/drift.dart';
import '../datasources/local_database.dart';
import '../../domain/entities/offline_action.dart';
import '../../domain/value_objects/action_status.dart';
import '../../domain/value_objects/action_type.dart';

class OfflineQueueRepository {
  final LocalDatabase db;

  OfflineQueueRepository({required this.db});

  Future<void> enqueue({
    required ActionType actionType,
    required String payload,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await db.into(db.offlineActionsTable).insert(
          OfflineActionsTableCompanion.insert(
            id: id,
            type: actionType.name,
            payload: payload,
            status: ActionStatus.pending.name,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<OfflineAction?> dequeue() async {
    final rows = await (db.select(db.offlineActionsTable)
          ..where((tbl) => tbl.status.equals(ActionStatus.pending.name))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.asc)])
          ..limit(1))
        .get();

    if (rows.isEmpty) return null;
    final row = rows.first;

    return OfflineAction(
      id: row.id,
      type: ActionType.values.byName(row.type),
      payload: jsonDecode(row.payload) as Map<String, dynamic>,
      status: ActionStatus.values.byName(row.status),
      createdAt: row.createdAt,
      retryCount: row.retryCount,
    );
  }

  Future<void> markAsSynced(String id) async {
    await (db.delete(db.offlineActionsTable)..where((tbl) => tbl.id.equals(id))).go();
  }
}
