import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/entities/user_profile.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/pending_approval_screen.dart';
import '../../features/student/presentation/screens/student_dashboard_screen.dart';
import '../../features/student/presentation/screens/profile_setup_screen.dart';
import '../../features/student/presentation/screens/consent_form_screen.dart';
import '../../features/student/presentation/screens/eligible_drives_screen.dart';
import '../../features/student/presentation/screens/drive_details_screen.dart';
import '../../features/student/presentation/screens/scan_attendance_screen.dart';
import '../../features/student/presentation/screens/student_application_timeline_screen.dart';
import '../../features/student/domain/entities/drive.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_reports_screen.dart';
import '../../features/admin/presentation/screens/tpo_appointment_screen.dart';
import '../../features/admin/presentation/screens/appoint_faculty_coordinator_screen.dart';
import '../../features/admin/presentation/screens/audit_logs_screen.dart';
import '../../features/admin/presentation/screens/system_settings_screen.dart';
import '../../features/admin/presentation/screens/course_management_screen.dart';
import '../../features/faculty/presentation/screens/faculty_dashboard_screen.dart';
import '../../features/faculty/presentation/screens/student_approval_queue_screen.dart';
import '../../features/faculty/presentation/screens/faculty_waiting_screen.dart';
import '../../features/faculty/presentation/screens/department_analytics_screen.dart';
import '../../features/tpo/presentation/screens/tpo_dashboard_screen.dart';
import '../../features/tpo/presentation/screens/drive_creation_wizard.dart';
import '../../features/tpo/presentation/screens/applicant_list_screen.dart';
import '../../features/tpo/presentation/screens/round_management_screen.dart';
import '../../features/tpo/presentation/screens/student_progress_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final rootNavigatorKey = _rootKey;

/// Global dashboard tab providers
final studentDashboardTabProvider = StateProvider<int>((ref) => 0);
final facultyDashboardTabProvider = StateProvider<int>((ref) => 0);
final tpoDashboardTabProvider = StateProvider<int>((ref) => 0);

/// Helper class to bridge Riverpod state changes to GoRouter's Listenable refresh
class GoRouterRefreshNotifier extends ChangeNotifier {
  late final ProviderSubscription _subscription;

  GoRouterRefreshNotifier(Ref ref) {
    _subscription = ref.listen<AsyncValue<UserProfile?>>(
      authNotifierProvider,
      (previous, next) => notifyListeners(),
    );
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final profile = authState.valueOrNull;
      final isLoggedIn = profile != null;

      final authPaths = {'/splash', '/login', '/signup', '/verify-otp', '/forgot-password'};
      final isOnAuth = authPaths.any((p) => state.matchedLocation.startsWith(p));

      // Still loading auth state — stay on splash screen
      if (authState.isLoading) {
        if (state.matchedLocation == '/splash') return null;
        return '/splash';
      }

      // Pending email OTP verification — keep the user on the OTP screen.
      final pendingOtp = ref.read(authNotifierProvider.notifier).pendingOtpEmail;
      if (pendingOtp != null && state.matchedLocation != '/verify-otp') {
        return '/verify-otp';
      }

      // Not logged in → must be on auth screen
      if (!isLoggedIn) {
        if (isOnAuth && state.matchedLocation != '/splash') return null;
        return '/login';
      }

      // Logged in → handle redirection based on role and approval status
      if (isLoggedIn) {
        // 1. If student has not verified email OTP, keep them on verify-otp
        if (profile.role == UserRole.student && !profile.emailVerified) {
          if (state.matchedLocation != '/verify-otp') {
            return '/verify-otp';
          }
          return null; // Already on verify-otp
        }

        // 2. Student Profile Collection Gate (Must enter all details first)
        if (profile.role == UserRole.student && !profile.profileCompleted) {
          if (state.matchedLocation != '/student/onboarding' &&
              state.matchedLocation != '/onboarding') {
            return '/student/onboarding';
          }
          return null; // Already on onboarding
        }

        // 3. Faculty Verification & Rejection Gate
        if (profile.role == UserRole.student &&
            (profile.approvalStatus == ApprovalStatus.pending ||
             profile.approvalStatus == ApprovalStatus.rejected)) {
          if (state.matchedLocation != '/pending-approval') {
            return '/pending-approval';
          }
          return null; // Already on pending-approval
        }

        // Otherwise, if they are on an auth screen or splash, redirect to their dashboard
        if (isOnAuth) {
          return _dashboardPath(profile.role);
        }

        // Enforce strict role-based route authorization
        if (profile.role == UserRole.faculty &&
            state.matchedLocation.startsWith('/faculty') &&
            state.matchedLocation != '/faculty/waiting') {
          return '/faculty/waiting';
        }

        // If they are on pending-approval but are approved, redirect to dashboard
        if (state.matchedLocation == '/pending-approval' &&
            (profile.role != UserRole.student ||
                (profile.approvalStatus != ApprovalStatus.pending &&
                 profile.approvalStatus != ApprovalStatus.rejected))) {
          return _dashboardPath(profile.role);
        }

        // If onboarding is done and they somehow land on /student/onboarding
        if (profile.role == UserRole.student &&
            profile.profileCompleted &&
            (state.matchedLocation == '/student/onboarding' ||
             state.matchedLocation == '/onboarding')) {
          return '/student';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        name: 'verify-otp',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return OtpVerificationScreen(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/pending-approval',
        name: 'pending-approval',
        builder: (_, __) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (_, __) => const ProfileSetupScreen(isEditMode: false),
      ),
      // ── Student routes ──────────────────────────────────────────────────
      GoRoute(
        path: '/student',
        name: 'student',
        builder: (_, __) => const StudentDashboardScreen(),
        routes: [
          GoRoute(
            path: 'onboarding',
            name: 'student-onboarding-nested',
            builder: (_, __) => const ProfileSetupScreen(isEditMode: false),
          ),
        ],
      ),
      GoRoute(
        path: '/student/onboarding',
        name: 'student-onboarding',
        builder: (_, __) => const ProfileSetupScreen(isEditMode: false),
      ),
      GoRoute(
        path: '/student/profile-edit',
        name: 'student-profile-edit',
        builder: (context, state) => ProfileSetupScreen(
          isEditMode: true,
          initialStep: state.extra as int? ?? 0,
        ),
      ),
      GoRoute(
        path: '/student/consent-form',
        name: 'student-consent-form',
        builder: (_, __) => const ConsentFormScreen(),
      ),
      GoRoute(
        path: '/student/eligible-drives',
        name: 'student-eligible-drives',
        builder: (_, __) => const EligibleDrivesScreen(),
      ),
      GoRoute(
        path: '/student/drive-details',
        name: 'student-drive-details',
        builder: (context, state) {
          final drive = state.extra as Drive;
          return DriveDetailsScreen(drive: drive);
        },
      ),
      GoRoute(
        path: '/student/scan-attendance',
        name: 'student-scan-attendance',
        builder: (_, __) => const ScanAttendanceScreen(),
      ),
      GoRoute(
        path: '/student/timeline',
        name: 'student-timeline',
        builder: (_, __) => const StudentApplicationTimelineScreen(),
      ),
      // ── Faculty routes ──────────────────────────────────────────────────
      GoRoute(
        path: '/faculty',
        name: 'faculty',
        builder: (_, __) => const FacultyDashboardScreen(),
      ),
      GoRoute(
        path: '/faculty/approval-queue',
        name: 'faculty-approval-queue',
        builder: (_, __) => const StudentApprovalQueueScreen(),
      ),
      GoRoute(
        path: '/faculty/waiting',
        name: 'faculty-waiting',
        builder: (_, __) => const FacultyWaitingScreen(),
      ),
      GoRoute(
        path: '/faculty/analytics',
        name: 'faculty-analytics',
        builder: (_, state) {
          final department = state.uri.queryParameters['dept'] ?? '';
          return DepartmentAnalyticsScreen(department: department);
        },
      ),
      // ── Admin routes ────────────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/reports',
        name: 'admin-reports',
        builder: (_, __) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: '/admin/appoint-tpo',
        name: 'admin-appoint-tpo',
        builder: (_, __) => const TpoAppointmentScreen(),
      ),
      GoRoute(
        path: '/admin/appoint-fc',
        name: 'admin-appoint-fc',
        builder: (_, __) => const AppointFacultyCoordinatorScreen(),
      ),
      GoRoute(
        path: '/admin/audit-logs',
        name: 'admin-audit-logs',
        builder: (_, __) => const AuditLogsScreen(),
      ),
      GoRoute(
        path: '/admin/settings',
        name: 'admin-settings',
        builder: (_, __) => const SystemSettingsScreen(),
      ),
      GoRoute(
        path: '/admin/courses',
        name: 'admin-courses',
        builder: (_, __) => const CourseManagementScreen(),
      ),
      // ── TPO routes ──────────────────────────────────────────────────────
      GoRoute(
        path: '/tpo',
        name: 'tpo',
        builder: (_, __) => const TpoDashboardScreen(),
      ),
      GoRoute(
        path: '/tpo/create-drive',
        name: 'tpo-create-drive',
        builder: (_, __) => const DriveCreationWizard(),
      ),
      GoRoute(
        path: '/tpo/applicant-list',
        name: 'tpo-applicant-list',
        builder: (_, __) => const ApplicantListScreen(),
      ),
      GoRoute(
        path: '/tpo/appoint-faculty',
        name: 'tpo-appoint-faculty',
        builder: (_, __) => const AppointFacultyCoordinatorScreen(),
      ),
      GoRoute(
        path: '/tpo/round-management',
        name: 'tpo-round-management',
        builder: (context, state) {
          final drive = state.extra as Drive;
          return RoundManagementScreen(drive: drive);
        },
      ),
      GoRoute(
        path: '/tpo/student-progress',
        name: 'tpo-student-progress',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return StudentProgressScreen(
            drive: extra['drive'] as Drive,
            applicationId: extra['applicationId'] as String,
            studentName: extra['studentName'] as String,
          );
        },
      ),
    ],
    errorBuilder: (context, state) {
      debugPrint('[GoRouter] Route error: ${state.error} for uri: ${state.uri}');
      if (state.uri.path.contains('onboarding')) {
        return const ProfileSetupScreen(isEditMode: false);
      }
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Not found: ${state.uri}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
});

final routerRefreshNotifierProvider = Provider<GoRouterRefreshNotifier>((ref) {
  return GoRouterRefreshNotifier(ref);
});

String _dashboardPath(UserRole role) {
  switch (role) {
    case UserRole.student:
      return '/student';
    case UserRole.facultyCoordinator:
      return '/faculty';
    case UserRole.faculty:
      return '/faculty/waiting';
    case UserRole.admin:
      return '/admin';
    case UserRole.tpo:
      return '/tpo';
  }
}


