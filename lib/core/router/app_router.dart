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
import '../../features/faculty/presentation/screens/department_analytics_screen.dart';
import '../../features/tpo/presentation/screens/tpo_dashboard_screen.dart';
import '../../features/tpo/presentation/screens/drive_creation_wizard.dart';
import '../../features/tpo/presentation/screens/applicant_list_screen.dart';
import '../../features/tpo/presentation/screens/round_management_screen.dart';
import '../../features/tpo/presentation/screens/student_progress_screen.dart';
import '../../features/tpo/presentation/screens/tpo_profile_screen.dart';
import '../theme/app_motion.dart';

final _rootKey = GlobalKey<NavigatorState>();
final rootNavigatorKey = _rootKey;

/// Smooth, high-performance page route transition helper matching global motion tokens.
Page<dynamic> buildAppPageTransition({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  if (AppMotion.isReducedMotion(context)) {
    return NoTransitionPage(key: state.pageKey, child: child);
  }

  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: AppMotion.emphasizedEasing),
      );

      final translationAnimation = Tween<Offset>(
        begin: const Offset(0.0, 0.012),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: animation, curve: AppMotion.emphasizedEasing),
      );

      final scaleAnimation = Tween<double>(begin: 0.985, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: AppMotion.emphasizedEasing),
      );

      return FadeTransition(
        opacity: opacityAnimation,
        child: SlideTransition(
          position: translationAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        ),
      );
    },
  );
}

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
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const SignupScreen(),
        ),
      ),
      GoRoute(
        path: '/verify-otp',
        name: 'verify-otp',
        pageBuilder: (context, state) {
          final email = state.extra as String? ?? '';
          return buildAppPageTransition(
            context: context,
            state: state,
            child: OtpVerificationScreen(email: email),
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/pending-approval',
        name: 'pending-approval',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const PendingApprovalScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const ProfileSetupScreen(isEditMode: false),
        ),
      ),
      // ── Student routes ──────────────────────────────────────────────────
      GoRoute(
        path: '/student',
        name: 'student',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const StudentDashboardScreen(),
        ),
        routes: [
          GoRoute(
            path: 'onboarding',
            name: 'student-onboarding-nested',
            pageBuilder: (context, state) => buildAppPageTransition(
              context: context,
              state: state,
              child: const ProfileSetupScreen(isEditMode: false),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/student/onboarding',
        name: 'student-onboarding',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const ProfileSetupScreen(isEditMode: false),
        ),
      ),
      GoRoute(
        path: '/student/profile-edit',
        name: 'student-profile-edit',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: ProfileSetupScreen(
            isEditMode: true,
            initialStep: state.extra as int? ?? 0,
          ),
        ),
      ),
      GoRoute(
        path: '/student/consent-form',
        name: 'student-consent-form',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const ConsentFormScreen(),
        ),
      ),
      GoRoute(
        path: '/student/eligible-drives',
        name: 'student-eligible-drives',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const EligibleDrivesScreen(),
        ),
      ),
      GoRoute(
        path: '/student/drive-details',
        name: 'student-drive-details',
        pageBuilder: (context, state) {
          final drive = state.extra is Drive ? state.extra as Drive : null;
          final driveId = state.uri.queryParameters['id'] ?? state.uri.queryParameters['drive_id'];
          return buildAppPageTransition(
            context: context,
            state: state,
            child: DriveDetailsScreen(drive: drive, driveId: driveId),
          );
        },
      ),
      GoRoute(
        path: '/student/drive/:id',
        name: 'student-drive-by-id',
        pageBuilder: (context, state) {
          final driveId = state.pathParameters['id'];
          final drive = state.extra is Drive ? state.extra as Drive : null;
          return buildAppPageTransition(
            context: context,
            state: state,
            child: DriveDetailsScreen(drive: drive, driveId: driveId),
          );
        },
      ),
      GoRoute(
        path: '/student/scan-attendance',
        name: 'student-scan-attendance',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const ScanAttendanceScreen(),
        ),
      ),
      GoRoute(
        path: '/student/timeline',
        name: 'student-timeline',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const StudentApplicationTimelineScreen(),
        ),
      ),
      // ── Faculty routes ──────────────────────────────────────────────────
      GoRoute(
        path: '/faculty',
        name: 'faculty',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const FacultyDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/faculty/approval-queue',
        name: 'faculty-approval-queue',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const StudentApprovalQueueScreen(),
        ),
      ),
      GoRoute(
        path: '/faculty/waiting',
        name: 'faculty-waiting',
        redirect: (context, state) => '/faculty',
      ),
      GoRoute(
        path: '/faculty/analytics',
        name: 'faculty-analytics',
        pageBuilder: (context, state) {
          final department = state.uri.queryParameters['dept'] ?? '';
          return buildAppPageTransition(
            context: context,
            state: state,
            child: DepartmentAnalyticsScreen(department: department),
          );
        },
      ),
      // ── Admin routes ────────────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        name: 'admin',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const AdminDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/reports',
        name: 'admin-reports',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const AdminReportsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/appoint-tpo',
        name: 'admin-appoint-tpo',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const TpoAppointmentScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/appoint-fc',
        name: 'admin-appoint-fc',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const AppointFacultyCoordinatorScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/audit-logs',
        name: 'admin-audit-logs',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const AuditLogsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/settings',
        name: 'admin-settings',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const SystemSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/courses',
        name: 'admin-courses',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const CourseManagementScreen(),
        ),
      ),
      // ── TPO routes ──────────────────────────────────────────────────────
      GoRoute(
        path: '/tpo',
        name: 'tpo',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const TpoDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/tpo/create-drive',
        name: 'tpo-create-drive',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const DriveCreationWizard(),
        ),
      ),
      GoRoute(
        path: '/tpo/applicant-list',
        name: 'tpo-applicant-list',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const ApplicantListScreen(),
        ),
      ),
      GoRoute(
        path: '/tpo/appoint-faculty',
        name: 'tpo-appoint-faculty',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const AppointFacultyCoordinatorScreen(),
        ),
      ),
      GoRoute(
        path: '/tpo/round-management',
        name: 'tpo-round-management',
        pageBuilder: (context, state) {
          final drive = state.extra as Drive;
          return buildAppPageTransition(
            context: context,
            state: state,
            child: RoundManagementScreen(drive: drive),
          );
        },
      ),
      GoRoute(
        path: '/tpo/student-progress',
        name: 'tpo-student-progress',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return buildAppPageTransition(
            context: context,
            state: state,
            child: StudentProgressScreen(
              drive: extra['drive'] as Drive,
              applicationId: extra['applicationId'] as String,
              studentName: extra['studentName'] as String,
            ),
          );
        },
      ),
      GoRoute(
        path: '/tpo/profile',
        name: 'tpo-profile',
        pageBuilder: (context, state) => buildAppPageTransition(
          context: context,
          state: state,
          child: const Scaffold(
            body: TpoProfileScreen(),
          ),
        ),
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
    case UserRole.faculty:
      return '/faculty';
    case UserRole.admin:
      return '/admin';
    case UserRole.tpo:
      return '/tpo';
  }
}


