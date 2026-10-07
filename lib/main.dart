import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  } catch (e) {
    debugPrint('[Main] Firebase initialization warning: $e');
  }

  // ── Supabase ──────────────────────────────────────────────────────────────
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  runApp(const ProviderScope(child: PlacementConnectApp()));
}

class PlacementConnectApp extends ConsumerStatefulWidget {
  const PlacementConnectApp({super.key});

  @override
  ConsumerState<PlacementConnectApp> createState() => _PlacementConnectAppState();
}

class _PlacementConnectAppState extends ConsumerState<PlacementConnectApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pushService = ref.read(pushNotificationServiceProvider);
      await pushService.initialize();
      pushService.processPendingRoute();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(pushNotificationServiceProvider).processPendingRoute();
    }
  }

  @override
  Future<bool> didPopRoute() async {
    // 1. If any modal, bottom sheet, or pushed screen can pop, pop it
    final nav = rootNavigatorKey.currentState;
    if (nav != null) {
      final handled = await nav.maybePop();
      if (handled) return true;
    }

    // 2. Identify current location in router
    final router = ref.read(appRouterProvider);
    final location = router.routerDelegate.currentConfiguration.uri.toString();

    // 3. Student pre-approval & registration flows (DO NOT send to dashboard)
    if (location == '/student/onboarding' || location == '/onboarding' || location == '/pending-approval') {
      return false; // Let PopScope handle step back or exit app. Never enter dashboard.
    }

    if (location == '/student' || location.startsWith('/student?')) {
      final tab = ref.read(studentDashboardTabProvider);
      if (tab != 0) {
        ref.read(studentDashboardTabProvider.notifier).state = 0;
        return true; // Returned to 1st page (Home)
      }
      return false; // Exit app from 1st page
    }
    if (location.startsWith('/student/')) {
      router.go('/student');
      return true;
    }

    // 4. Faculty flow
    if (location == '/faculty' || location.startsWith('/faculty?')) {
      final tab = ref.read(facultyDashboardTabProvider);
      if (tab != 0) {
        ref.read(facultyDashboardTabProvider.notifier).state = 0;
        return true; // Returned to 1st page (Home)
      }
      return false; // Exit app from 1st page
    }
    if (location.startsWith('/faculty/')) {
      router.go('/faculty');
      return true;
    }

    // 5. TPO flow
    if (location == '/tpo' || location.startsWith('/tpo?')) {
      final tab = ref.read(tpoDashboardTabProvider);
      if (tab != 0) {
        ref.read(tpoDashboardTabProvider.notifier).state = 0;
        return true; // Returned to 1st page (Home)
      }
      return false; // Exit app from 1st page
    }
    if (location.startsWith('/tpo/')) {
      router.go('/tpo');
      return true;
    }

    // 6. Admin flow
    if (location == '/admin' || location.startsWith('/admin?')) {
      return false; // Exit app from 1st page
    }
    if (location.startsWith('/admin/')) {
      router.go('/admin');
      return true;
    }

    // Default for auth or other screens
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}