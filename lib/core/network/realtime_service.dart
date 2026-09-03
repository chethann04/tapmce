import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeManager {
  final SupabaseClient _supabase;
  WebSocketChannel? _rawWebSocket;
  Timer? _heartbeatTimer;
  int _retryAttempt = 0;
  final List<int> _backoffDelays = [1, 2, 4, 8, 16, 30, 60];
  final Map<String, RealtimeChannel> _activeChannels = {};

  RealtimeManager(this._supabase) {
    _startHeartbeat();
  }

  void connectWebSocketChannel(String url) {
    try {
      _rawWebSocket = WebSocketChannel.connect(Uri.parse(url));
    } catch (_) {}
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      final isAlive = _supabase.realtime.isConnected;
      if (!isAlive) {
        await reconnect();
      }
    });
  }

  Future<void> reconnect() async {
    final delay = _backoffDelays[(_retryAttempt < _backoffDelays.length) ? _retryAttempt : _backoffDelays.length - 1];
    _retryAttempt++;
    await Future.delayed(Duration(seconds: delay));
    try {
      // ignore: invalid_use_of_internal_member
      _supabase.realtime.connect();
      _retryAttempt = 0;
    } catch (_) {}
  }

  RealtimeChannel subscribeToTableChanges({
    required String table,
    required void Function(Map<String, dynamic> payload) onData,
  }) {
    if (_activeChannels.containsKey(table)) {
      return _activeChannels[table]!;
    }

    final channel = _supabase.channel('public:$table');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (payload) {
        onData(payload.newRecord);
      },
    ).subscribe();

    _activeChannels[table] = channel;
    return channel;
  }

  void unsubscribe(String table) {
    if (_activeChannels.containsKey(table)) {
      _supabase.removeChannel(_activeChannels[table]!);
      _activeChannels.remove(table);
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _rawWebSocket?.sink.close();
    for (final channel in _activeChannels.values) {
      _supabase.removeChannel(channel);
    }
    _activeChannels.clear();
  }
}