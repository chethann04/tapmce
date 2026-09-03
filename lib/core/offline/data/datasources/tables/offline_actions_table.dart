import 'package:drift/drift.dart';

class OfflineActionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get payload => text()(); // Store payload as JSON string
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
