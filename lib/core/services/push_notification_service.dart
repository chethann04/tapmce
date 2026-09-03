import 'dart:developer' as dev;



import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(Supabase.instance.client);
});

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  dev.log('[PushNotificationService] Background message: ${message.messageId}');
}

class PushNotificationService {
  final SupabaseClient _supabase;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  PushNotificationService(this._supabase);

  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        dev.log('[PushNotificationService] Web push skipped natively, assuming Supabase realtime fallback.');
        return;
      }

      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin);

      await _localNotificationsPlugin.initialize(settings: initializationSettings);

      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'tap_app_notifications',
          'TAP App Notifications',
          description: 'Important updates and alerts from the TPO',
          importance: Importance.max,
          playSound: true,
        );
        await androidPlugin.createNotificationChannel(channel);
        await androidPlugin.requestNotificationsPermission();
      }

      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      dev.log('[PushNotificationService] User granted permission: ${settings.authorizationStatus}');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        dev.log('[PushNotificationService] Foreground message: ${message.messageId}');
        _showForegroundNotification(message);
      });

      dev.log('[PushNotificationService] FCM + Local Notifications Initialized.', name: 'PushNotificationService');
    } catch (e) {
      dev.log('[PushNotificationService] Failed to initialize: $e', name: 'PushNotificationService', error: e);
    }
  }

  RealtimeChannel? _notificationChannel;

  /// Shows an instant system heads-up notification banner on the device
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'tap_app_notifications',
        'TAP App Notifications',
        channelDescription: 'Important updates and alerts from the TPO',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _localNotificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e) {
      dev.log('[PushNotificationService] Failed to show local notification: $e');
    }
  }

  /// Subscribes to the Supabase notifications table in real-time.
  /// Whenever a notification record is created for this user, it immediately
  /// displays a system heads-up notification banner on the device.
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
              dev.log('[PushNotificationService] Realtime notification received: $title');
              showLocalNotification(
                title: title,
                body: body,
                payload: newRecord['drive_id'] as String?,
              );
            },
          );
      _notificationChannel?.subscribe();
      dev.log('[PushNotificationService] Subscribed to realtime notifications for user: $userId');
    } catch (e) {
      dev.log('[PushNotificationService] Error subscribing to realtime notifications: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
            'tap_app_notifications', 'TAP App Notifications',
            channelDescription: 'Important updates and alerts from the TPO',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _localNotificationsPlugin.show(
        id: notification.hashCode, title: notification.title, body: notification.body, notificationDetails: notificationDetails, payload: message.data.toString());
  }

  Future<void> registerDeviceToken() async {
    if (kIsWeb) return;
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        dev.log('[PushNotificationService] FCM Token: $token');
        await _supabase.from('fcm_tokens').upsert({
          'user_id': user.id,
          'token': token,
          'platform': defaultTargetPlatform.name.toLowerCase()
        }, onConflict: 'token');
        dev.log('[PushNotificationService] Token synced to Supabase (fcm_tokens).');
      }
    } catch (e) {
      dev.log('[PushNotificationService] Token registration failed: $e');
    }
  }

  Future<void> unregisterDeviceToken() async {
    if (kIsWeb) return;
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.from('fcm_tokens').delete().eq('user_id', user.id);
      }
      await FirebaseMessaging.instance.deleteToken();
      dev.log('[PushNotificationService] Token unregistered.');
    } catch (e) {
      dev.log('[PushNotificationService] Unregistration skipped/failed: $e');
    }
  }
}


