import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../network/connectivity_service.dart';

final connectivityServiceProvider = Provider((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

final isOnlineStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onStatusChanged.map((status) => status == NetworkStatus.online);
});