import 'package:freezed_annotation/freezed_annotation.dart';
import '../value_objects/action_status.dart';
import '../value_objects/action_type.dart';

part 'offline_action.freezed.dart';

@freezed
class OfflineAction with _$OfflineAction {
  const factory OfflineAction({
    required String id,
    required ActionType type,
    required Map<String, dynamic> payload,
    required ActionStatus status,
    required DateTime createdAt,
    int? retryCount,
  }) = _OfflineAction;
}
