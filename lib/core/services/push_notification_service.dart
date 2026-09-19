import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import '../router/app_router.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(Supabase.instance.client);
});

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    dev.log('[FCM] Background message received: ${message.messageId} | data: ${message.data}');
  } catch (e) {
    dev.log('[FCM] Error in background message handler: $e');
  }
}

class PushNotificationService {
  final SupabaseClient _supabase;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  RealtimeChannel? _notificationChannel;

  PushNotificationService(this._supabase);

  /// Initializes FCM listeners, permissions, local notifications channel, and cold-start handler
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (kIsWeb) {
        dev.log('[FCM] Web push skipped natively, relying on Supabase realtime fallback.');
        return;
      }

      dev.log('[FCM] Initializing Firebase Messaging');

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Setup Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          dev.log('[FCM] Local notification tapped with payload: ${response.payload}');
          _handlePayloadRouting(response.payload);
        },
      );

      // Create high importance Android notification channel
      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'Used for important recruitment and drive updates',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(channel);
      }

      // Request FCM permissions
      final settings = await requestPermission();
      dev.log('[FCM] Permission status: ${settings.authorizationStatus}');

      // 1. Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        dev.log('[FCM] Foreground message received: ${message.messageId} | title: ${message.notification?.title}');
        _showForegroundNotification(message);
      });

      // 2. Background message tap handler (App in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        dev.log('[FCM] Notification opened from background: ${message.messageId} | data: ${message.data}');
        _handleMessageRouting(message.data);
      });

      // 3. Cold-start message handler (App was completely terminated)
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        dev.log('[FCM] Cold-start notification detected: ${initialMessage.messageId} | data: ${initialMessage.data}');
        _handleMessageRouting(initialMessage.data);
      }

      // 4. Token refresh listener
      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
        final maskedToken = newToken.length > 10 ? '${newToken.substring(0, 8)}...${newToken.substring(newToken.length - 4)}' : newToken;
        dev.log('[FCM] Token refreshed: $maskedToken');
        final user = _supabase.auth.currentUser;
        if (user != null) {
          try {
            await _supabase.from('fcm_tokens').upsert({
              'user_id': user.id,
              'token': newToken,
              'platform': defaultTargetPlatform.name.toLowerCase(),
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'token');
            dev.log('[FCM] Refreshed token synced to Supabase.');
          } catch (e) {
            dev.log('[FCM] Failed to sync refreshed token: $e');
          }
        }
      });

      _initialized = true;
      dev.log('[FCM] Push Notification Service successfully initialized.');
    } catch (e) {
      dev.log('[FCM] Failed to initialize push service: $e');
    }
  }

  /// Explicitly requests notification permissions from the OS
  Future<NotificationSettings> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // On Android 13+, request POST_NOTIFICATIONS runtime permission if available
    try {
      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (_) {}

    return settings;
  }

  /// Retrieves current device FCM token
  Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        final masked = token.length > 10 ? '${token.substring(0, 8)}...${token.substring(token.length - 4)}' : token;
        dev.log('[FCM] Token received: $masked');
      }
      return token;
    } catch (e) {
      dev.log('[FCM] Error getting FCM token: $e');
      return null;
    }
  }

  /// Registers and upserts current device FCM token to Supabase (fcm_tokens table)
  Future<void> registerDeviceToken() async {
    if (kIsWeb) return;
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final token = await getToken();
      if (token != null) {
        await _supabase.from('fcm_tokens').upsert({
          'user_id': user.id,
          'token': token,
          'platform': defaultTargetPlatform.name.toLowerCase(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'token');
        dev.log('[FCM] Device token registered to Supabase for user: ${user.id}');
      }
    } catch (e) {
      dev.log('[FCM] Token registration failed: $e');
    }
  }

  /// Unregisters and removes device FCM token from Supabase on logout
  Future<void> unregisterDeviceToken() async {
    if (kIsWeb) return;
    try {
      final token = await getToken();
      if (token != null) {
        await _supabase.from('fcm_tokens').delete().eq('token', token);
      }
      await FirebaseMessaging.instance.deleteToken();
      dev.log('[FCM] Device token deleted.');
    } catch (e) {
      dev.log('[FCM] Unregistration notice: $e');
    }
  }

  /// Displays local heads-up notification in foreground
  void _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Placement Connect';
    final body = notification?.body ?? message.data['body'] ?? '';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Used for important recruitment and drive updates',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    final payloadString = message.data.isNotEmpty ? message.data.toString() : (message.data['drive_id'] ?? '');

    await _localNotificationsPlugin.show(
      id: notification.hashCode != 0 ? notification.hashCode : DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payloadString,
    );
  }

  /// Shows manual local notification banner
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'Used for important recruitment and drive updates',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

      await _localNotificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      dev.log('[FCM] Failed to show local notification: $e');
    }
  }

  /// Subscribes to Supabase realtime notifications table
  void listenToRealtimeNotifications(String userId) {
    _notificationChannel?.unsubscribe();
    try {
      _notificationChannel = _supabase
          .channel('public:notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final newRecord = payload.newRecord;
              final title = newRecord['title'] as String? ?? 'Placement Connect';
              final body = newRecord['body'] as String? ?? '';
              dev.log('[FCM] Realtime notification received: $title');
              showLocalNotification(
                title: title,
                body: body,
                payload: newRecord['drive_id'] as String?,
              );
            },
          );
      _notificationChannel?.subscribe();
      dev.log('[FCM] Subscribed to realtime notifications for user: $userId');
    } catch (e) {
      dev.log('[FCM] Error subscribing to realtime notifications: $e');
    }
  }

  /// Deep link routing handler for message payloads
  void _handleMessageRouting(Map<String, dynamic> data) {
    dev.log('[FCM] Deep link routing: $data');
    final driveId = data['drive_id'] ?? data['driveId'];
    final screen = data['screen'] ?? data['type'];
    final navContext = rootNavigatorKey.currentContext;

    if (navContext == null) {
      dev.log('[FCM] Navigation context null, queueing route');
      return;
    }

    try {
      if (driveId != null && driveId.toString().isNotEmpty) {
        GoRouter.of(navContext).push('/student/drive/$driveId');
      } else if (screen == 'notifications' || screen == 'timeline') {
        GoRouter.of(navContext).push('/student/timeline');
      }
    } catch (e) {
      dev.log('[FCM] Navigation error: $e');
    }
  }

  /// Handles payload string from local notification tap
  void _handlePayloadRouting(String? payload) {
    if (payload == null || payload.isEmpty) return;
    dev.log('[FCM] Local notification payload: $payload');
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) return;

    try {
      if (payload.startsWith('{') && payload.endsWith('}')) {
        // Formatted map payload
        if (payload.contains('drive_id:')) {
          final match = RegExp(r'drive_id:\s*([a-zA-Z0-9_-]+)').firstMatch(payload);
          if (match != null && match.group(1) != null) {
            GoRouter.of(navContext).push('/student/drive/${match.group(1)}');
            return;
          }
        }
      } else {
        // Plain drive ID payload
        GoRouter.of(navContext).push('/student/drive/$payload');
      }
    } catch (e) {
      dev.log('[FCM] Local payload routing error: $e');
    }
  }

  /// Dispatches a test notification to the current authenticated user via Supabase send-fcm-push Edge Function
  Future<Map<String, dynamic>> sendTestPushNotification() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'error': 'User not authenticated.'};
    }

    try {
      dev.log('[FCM] Dispatching test push notification for user: ${user.id}');
      final response = await _supabase.functions.invoke(
        'send-fcm-push',
        body: {
          'user_ids': [user.id],
          'title': 'Placement Connect Test 🔔',
          'body': 'Push notifications are working successfully!',
          'type': 'test',
          'screen': 'notifications',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final data = response.data is Map ? (response.data as Map) : <String, dynamic>{};
      final isSuccess = response.status == 200 && data['success'] == true;

      dev.log('[FCM] Test push dispatch result: status=${response.status}, data=$data');
      return {
        'success': isSuccess,
        'status': response.status,
        'data': data,
      };
    } catch (e) {
      dev.log('[FCM] Test push dispatch error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}


