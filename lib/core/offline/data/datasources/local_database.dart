import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables/offline_actions_table.dart';

part 'local_database.g.dart';

@DriftDatabase(tables: [OfflineActionsTable])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_offline_queue.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}