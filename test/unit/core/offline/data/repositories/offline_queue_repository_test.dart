import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:placement_connect/core/offline/data/datasources/local_database.dart';
import 'package:placement_connect/core/offline/data/repositories/offline_queue_repository.dart';
import 'package:placement_connect/core/offline/domain/value_objects/action_status.dart';
import 'package:placement_connect/core/offline/domain/value_objects/action_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase db;
  late OfflineQueueRepository repository;

  setUp(() {
    db = LocalDatabase(NativeDatabase.memory());
    repository = OfflineQueueRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('OfflineQueueRepository', () {
    test('enqueue and dequeue returns the same action', () async {
      const payload = '{"drive_id": "abc"}';

      await repository.enqueue(actionType: ActionType.applyToDrive, payload: payload);
      final action = await repository.dequeue();

      expect(action, isNotNull);
      expect(action!.type, ActionType.applyToDrive);
      expect(action.payload, {'drive_id': 'abc'});
      expect(action.status, ActionStatus.pending);
    });

    test('dequeue returns null when queue is empty', () async {
      final action = await repository.dequeue();
      expect(action, isNull);
    });

    test('markAsSynced removes the action from the queue', () async {
      await repository.enqueue(actionType: ActionType.updateProfile, payload: '{}');
      final action = await repository.dequeue();
      expect(action, isNotNull);

      await repository.markAsSynced(action!.id);
      final nextAction = await repository.dequeue();

      expect(nextAction, isNull);
    });
  });
}