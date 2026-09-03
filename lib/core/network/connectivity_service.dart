import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus {
  online,
  offline,
  poorConnection,
  connecting,
  reconnecting,
  disconnected,
}

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkStatus> _statusController = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _currentStatus = NetworkStatus.connecting;

  ConnectivityService() {
    _init();
  }

  NetworkStatus get currentStatus => _currentStatus;
  Stream<NetworkStatus> get onStatusChanged => _statusController.stream;

  void _init() {
    _connectivity.onConnectivityChanged.listen((results) async {
      final hasHardware = results.any((r) => r != ConnectivityResult.none);
      if (!hasHardware) {
        _updateStatus(NetworkStatus.offline);
      } else {
        _updateStatus(NetworkStatus.connecting);
        final verified = await verifyInternetConnection();
        _updateStatus(verified ? NetworkStatus.online : NetworkStatus.poorConnection);
      }
    });
  }

  Future<bool> verifyInternetConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  void _updateStatus(NetworkStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    _statusController.close();
  }
}