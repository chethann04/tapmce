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
    debugPrint('[FCM] Background message received: ${message.messageId} | data: ${message.data}');
    dev.log('[FCM] Background message received: ${message.messageId} | data: ${message.data}');
  } catch (e) {
    debugPrint('[FCM] Error in background message handler: $e');
    dev.log('[FCM] Error in background message handler: $e');
  }
}

class PushNotificationService {
  final SupabaseClient _supabase;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  RealtimeChannel? _notificationChannel;
  String? _pendingRoute;

  // ── Diagnostic State Tracking (Phase 18) ──────────────────────────────────
  bool _isFirebaseInitialized = false;
  String _permissionStatus = 'notDetermined';
  String? _currentFcmToken;
  int? _tokenLength;
  String? _tokenPrefix;
  bool _isTokenStoredInSupabase = false;
  String? _tokenRegistrationStatus;
  String? _lastFcmOnMessage;
  String? _lastFcmError;
  bool _hasNotificationChannel = false;

  bool get isFirebaseInitialized => _isFirebaseInitialized;
  String get permissionStatus => _permissionStatus;
  String? get currentFcmToken => _currentFcmToken;
  int? get tokenLength => _tokenLength;
  String? get tokenPrefix => _tokenPrefix;
  bool get isTokenStoredInSupabase => _isTokenStoredInSupabase;
  String? get tokenRegistrationStatus => _tokenRegistrationStatus;
  String? get lastFcmOnMessage => _lastFcmOnMessage;
  String? get lastFcmError => _lastFcmError;
  bool get hasNotificationChannel => _hasNotificationChannel;
  String? get pendingRoute => _pendingRoute;

  PushNotificationService(this._supabase);

  /// Initializes FCM listeners, permissions, local notifications channel, and cold-start handler
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (kIsWeb) {
        debugPrint('[FCM] Web push skipped natively, relying on Supabase realtime fallback.');
        return;
      }

      debugPrint('[FCM] Initializing Firebase Messaging');

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isFirebaseInitialized = true;

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
          debugPrint('[FCM] Local notification tapped with payload: ${response.payload}');
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
        _hasNotificationChannel = true;
      }

      // Request FCM permissions
      final settings = await requestPermission();
      _permissionStatus = settings.authorizationStatus.name;

      // 1. Foreground message handler (Phase 11)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _lastFcmOnMessage = DateTime.now().toIso8601String();
        debugPrint('==================================================');
        debugPrint('[FCM] FCM onMessage RECEIVED');
        debugPrint('[FCM] messageId: ${message.messageId}');
        debugPrint('[FCM] title: ${message.notification?.title ?? message.data['title']}');
        debugPrint('[FCM] body: ${message.notification?.body ?? message.data['body']}');
        debugPrint('[FCM] data: ${message.data}');
        debugPrint('==================================================');
        _showForegroundNotification(message);
      });

      // 2. Background message tap handler (App in background - Phase 12)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM] Notification opened from background: ${message.messageId} | data: ${message.data}');
        _handleMessageRouting(message.data);
      });

      // 3. Cold-start message handler (App was completely terminated - Phase 13)
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] Cold-start notification detected: ${initialMessage.messageId} | data: ${initialMessage.data}');
        _handleMessageRouting(initialMessage.data);
      }

      // 4. Token refresh listener
      FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
        _currentFcmToken = newToken;
        _tokenLength = newToken.length;
        _tokenPrefix = newToken.length > 8 ? '${newToken.substring(0, 8)}...' : newToken;
        debugPrint('[FCM] Token refreshed: $_tokenPrefix (length: $_tokenLength)');
        final user = _supabase.auth.currentUser;
        if (user != null) {
          await registerDeviceToken();
        }
      });

      // Retrieve token & log initial startup diagnostics (Phase 2)
      final token = await getToken();
      String regResult = 'SKIPPED (no authenticated user yet)';
      final user = _supabase.auth.currentUser;
      if (user != null && token != null) {
        final success = await registerDeviceToken();
        regResult = success ? 'SUCCESS' : 'FAILURE';
      }

      debugPrint('==================================================');
      debugPrint('[FCM] FCM INITIALIZATION STARTED');
      debugPrint('[FCM] Firebase initialized: $_isFirebaseInitialized');
      debugPrint('[FCM] Notification permission: $_permissionStatus');
      debugPrint('[FCM] FCM token available: ${token != null}');
      debugPrint('[FCM] FCM token length: ${_tokenLength ?? 0}');
      debugPrint('[FCM] FCM token prefix: ${_tokenPrefix ?? "null"}');
      debugPrint('[FCM] Supabase user ID: ${user?.id ?? "null (unauthenticated)"}');
      debugPrint('[FCM] Token registration result: $regResult');
      debugPrint('==================================================');

      _initialized = true;
    } catch (e) {
      _lastFcmError = e.toString();
      debugPrint('[FCM] Failed to initialize push service: $e');
    }
  }

  /// Explicitly requests notification permissions from the OS (Phase 10)
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
    _permissionStatus = settings.authorizationStatus.name;

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

  /// Retrieves current device FCM token (Phase 2)
  Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _currentFcmToken = token;
        _tokenLength = token.length;
        _tokenPrefix = token.length > 8 ? '${token.substring(0, 8)}...' : token;
        debugPrint('[FCM] Token received: $_tokenPrefix (length: $_tokenLength)');
      } else {
        debugPrint('[FCM] Token received: NULL');
      }
      return token;
    } catch (e) {
      _lastFcmError = e.toString();
      debugPrint('[FCM] Error getting FCM token: $e');
      return null;
    }
  }

  /// Deletes cached token and fetches a brand-new token from current Firebase project
  Future<String?> refreshToken() async {
    if (kIsWeb) return null;
    try {
      debugPrint('[FCM] Deleting old cached FCM token...');
      await FirebaseMessaging.instance.deleteToken();
      final newToken = await FirebaseMessaging.instance.getToken();
      if (newToken != null) {
        _currentFcmToken = newToken;
        _tokenLength = newToken.length;
        _tokenPrefix = newToken.length > 8 ? '${newToken.substring(0, 8)}...' : newToken;
        debugPrint('[FCM] Fresh token obtained: $_tokenPrefix');
        await registerDeviceToken();
      }
      return newToken;
    } catch (e) {
      _lastFcmError = e.toString();
      debugPrint('[FCM] Error refreshing FCM token: $e');
      return null;
    }
  }

  /// Registers and upserts current device FCM token to Supabase (Phase 4)
  /// Note: The remote Supabase table schema uses columns:
  ///   user_id (UUID), fcm_token (TEXT), device_type (TEXT), updated_at (TIMESTAMPTZ)
  ///   Unique constraint: (user_id, fcm_token)
  Future<bool> registerDeviceToken() async {
    if (kIsWeb) return false;
    final user = _supabase.auth.currentUser;
    debugPrint('==================================================');
    debugPrint('[FCM] FCM TOKEN UPSERT START');
    debugPrint('[FCM] Supabase user ID: ${user?.id ?? "null (unauthenticated)"}');

    if (user == null) {
      debugPrint('[FCM] FCM TOKEN UPSERT FAILED: No authenticated Supabase user');
      debugPrint('==================================================');
      _tokenRegistrationStatus = 'FAILED: User not logged in';
      return false;
    }

    final token = await getToken();
    if (token == null) {
      debugPrint('[FCM] FCM TOKEN UPSERT FAILED: Device FCM token is null');
      debugPrint('==================================================');
      _tokenRegistrationStatus = 'FAILED: Token is null';
      return false;
    }

    try {
      final platform = defaultTargetPlatform.name.toLowerCase();
      final now = DateTime.now().toIso8601String();

      // Verified live database schema: fcm_token, device_type, user_id, updated_at
      await _supabase.from('fcm_tokens').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'device_type': platform,
        'updated_at': now,
      }, onConflict: 'user_id,fcm_token');

      _isTokenStoredInSupabase = true;
      _tokenRegistrationStatus = 'SUCCESS';
      debugPrint('[FCM] FCM TOKEN UPSERT SUCCESS');
      debugPrint('[FCM] User: ${user.id} | Platform: $platform | Token: $_tokenPrefix');
      debugPrint('==================================================');
      return true;
    } on PostgrestException catch (pgErr) {
      _isTokenStoredInSupabase = false;
      _tokenRegistrationStatus = 'FAILED: ${pgErr.message}';
      _lastFcmError = 'Postgres ${pgErr.code}: ${pgErr.message}';
      debugPrint('[FCM] FCM TOKEN UPSERT FAILED');
      debugPrint('[FCM] HTTP STATUS: ${pgErr.code}');
      debugPrint('[FCM] POSTGRES ERROR: ${pgErr.code}');
      debugPrint('[FCM] MESSAGE: ${pgErr.message}');
      debugPrint('[FCM] DETAIL: ${pgErr.details}');
      debugPrint('[FCM] HINT: ${pgErr.hint}');
      debugPrint('==================================================');
      return false;
    } catch (e) {
      _isTokenStoredInSupabase = false;
      _tokenRegistrationStatus = 'FAILED: $e';
      _lastFcmError = e.toString();
      debugPrint('[FCM] FCM TOKEN UPSERT FAILED');
      debugPrint('[FCM] ERROR: $e');
      debugPrint('==================================================');
      return false;
    }
  }

  /// Verifies whether the current device token actually exists in Supabase (Phase 3)
  Future<bool> checkTokenInDatabase() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final token = await getToken();
    if (token == null) return false;

    try {
      final rows = await _supabase
          .from('fcm_tokens')
          .select('id, user_id, fcm_token, device_type, updated_at')
          .eq('user_id', user.id)
          .eq('fcm_token', token);

      final exists = (rows as List).isNotEmpty;
      _isTokenStoredInSupabase = exists;
      debugPrint('[FCM] Database check for device token: ${exists ? "FOUND" : "NOT FOUND"} (matching rows: ${rows.length})');
      return exists;
    } catch (e) {
      debugPrint('[FCM] Database token check error: $e');
      return false;
    }
  }

  /// Unregisters and removes device FCM token from Supabase on logout
  Future<void> unregisterDeviceToken() async {
    if (kIsWeb) return;
    try {
      final token = await getToken();
      if (token != null) {
        await _supabase.from('fcm_tokens').delete().eq('fcm_token', token);
      }
      await FirebaseMessaging.instance.deleteToken();
      _isTokenStoredInSupabase = false;
      _currentFcmToken = null;
      _tokenPrefix = null;
      _tokenLength = null;
      debugPrint('[FCM] Device token deleted.');
    } catch (e) {
      debugPrint('[FCM] Unregistration notice: $e');
    }
  }

  /// Displays local heads-up notification in foreground (Phase 11)
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
      debugPrint('[FCM] Failed to show local notification: $e');
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
              debugPrint('[FCM] Realtime notification received: $title');
              showLocalNotification(
                title: title,
                body: body,
                payload: newRecord['drive_id'] as String?,
              );
            },
          );
      _notificationChannel?.subscribe();
      debugPrint('[FCM] Subscribed to realtime notifications for user: $userId');
    } catch (e) {
      debugPrint('[FCM] Error subscribing to realtime notifications: $e');
    }
  }

  /// Deep link routing handler for message payloads (Phase 13 & 14)
  void _handleMessageRouting(Map<String, dynamic> data) {
    debugPrint('[FCM] Deep link routing: $data');
    final driveId = data['drive_id'] ?? data['driveId'] ?? data['id'];
    final screen = data['screen'] ?? data['type'];
    final explicitRoute = data['route'] as String?;

    String? targetRoute;
    if (explicitRoute != null && explicitRoute.isNotEmpty) {
      targetRoute = explicitRoute;
    } else if (driveId != null && driveId.toString().isNotEmpty) {
      targetRoute = '/student/drive/$driveId';
    } else if (screen == 'notifications' || screen == 'timeline') {
      targetRoute = '/student/timeline';
    }

    if (targetRoute == null) return;

    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) {
      debugPrint('[FCM] Navigation context null, queueing route: $targetRoute');
      _pendingRoute = targetRoute;
      return;
    }

    try {
      GoRouter.of(navContext).push(targetRoute);
    } catch (e) {
      debugPrint('[FCM] Navigation error: $e, storing as pending route');
      _pendingRoute = targetRoute;
    }
  }

  /// Dispatches any queued pending routes once navigation context is ready
  void processPendingRoute() {
    if (_pendingRoute == null) return;
    final navContext = rootNavigatorKey.currentContext;
    if (navContext != null) {
      final route = _pendingRoute!;
      _pendingRoute = null;
      try {
        debugPrint('[FCM] Dispatching pending deep link route: $route');
        GoRouter.of(navContext).push(route);
      } catch (e) {
        debugPrint('[FCM] Pending route navigation failed: $e');
      }
    }
  }

  /// Handles payload string from local notification tap
  void _handlePayloadRouting(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('[FCM] Local notification payload: $payload');

    String? targetRoute;
    if (payload.startsWith('/')) {
      targetRoute = payload;
    } else if (payload.startsWith('{') && payload.endsWith('}')) {
      if (payload.contains('drive_id:')) {
        final match = RegExp(r'drive_id:\s*([a-zA-Z0-9_-]+)').firstMatch(payload);
        if (match != null && match.group(1) != null) {
          targetRoute = '/student/drive/${match.group(1)}';
        }
      }
    } else {
      targetRoute = '/student/drive/$payload';
    }

    if (targetRoute == null) return;

    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) {
      debugPrint('[FCM] Navigation context null for local payload, queueing route: $targetRoute');
      _pendingRoute = targetRoute;
      return;
    }

    try {
      GoRouter.of(navContext).push(targetRoute);
    } catch (e) {
      debugPrint('[FCM] Local payload routing error: $e');
      _pendingRoute = targetRoute;
    }
  }

  /// Dispatches a test notification to the current authenticated user via Supabase send-fcm-push (Phase 5)
  Future<Map<String, dynamic>> sendTestPushNotification() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'success': false, 'error': 'User not authenticated.'};
    }

    try {
      debugPrint('[FCM] Dispatching test push notification for user: ${user.id}');
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

      debugPrint('[FCM] Test push dispatch result: status=${response.status}, data=$data');
      return {
        'success': isSuccess,
        'status': response.status,
        'data': data,
      };
    } catch (e) {
      debugPrint('[FCM] Test push dispatch error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sends a raw push notification directly to a single known FCM token (Phase 14)
  Future<Map<String, dynamic>> sendRawTokenPushTest({required String token}) async {
    try {
      final masked = token.length > 8 ? '${token.substring(0, 8)}...' : token;
      debugPrint('[FCM] Dispatching raw token push test to: $masked');

      final response = await _supabase.functions.invoke(
        'send-fcm-push',
        body: {
          'token': token,
          'title': 'Raw FCM Test 🔔',
          'body': 'Direct single-token FCM push verified at ${DateTime.now().toIso8601String()}',
          'type': 'test_raw',
          'screen': 'notifications',
        },
      );

      final data = response.data is Map ? (response.data as Map) : <String, dynamic>{};
      final isSuccess = response.status == 200 && data['success'] == true;

      debugPrint('[FCM] Raw token push test result: status=${response.status}, data=$data');
      return {
        'success': isSuccess,
        'status': response.status,
        'data': data,
      };
    } catch (e) {
      debugPrint('[FCM] Raw token push test error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
