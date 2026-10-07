import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/user_profile.dart';
import '../../../audit/domain/entities/audit_log_entry.dart';
import '../../../audit/domain/repositories/audit_log_repository.dart';
import '../../../../core/services/email_notification_service.dart';
import '../../../../core/services/push_notification_service.dart';

// ── Datasource provider ────────────────────────────────────────────────────
final authDatasourceProvider = Provider<AuthRemoteDatasource>((ref) {
  return AuthRemoteDatasource(Supabase.instance.client);
});

// ── Auth state stream (logged in / out) ───────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authDatasourceProvider).authStateChanges;
});

// ── Current user profile ───────────────────────────────────────────────────
final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.when(
    data: (authState) async {
      final user = authState.session?.user;
      if (user == null) return null;
      return ref.read(authDatasourceProvider).fetchProfile(user.id);
    },
    loading: () async => null,
    error: (_, __) async => null,
  );
});

// ── Auth notifier (actions & active state) ─────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRemoteDatasource _datasource;
  final AuditLogRepository _auditLogRepo;
  final EmailNotificationService? _emailService;
  final PushNotificationService? _pushService;
  RealtimeChannel? _profileChannel;

  /// Set while a signup is waiting on email OTP verification. Lets the router
  /// keep the user on the OTP screen.
  String? _pendingOtpEmail;
  String? _pendingPassword;
  String? _lastOtpError;

  String? get pendingOtpEmail => _pendingOtpEmail;
  String? get lastOtpError => _lastOtpError;

  /// Abandons an in-progress OTP session (e.g. user leaves the OTP screen).
  void clearPendingOtp() {
    _pendingOtpEmail = null;
    _pendingPassword = null;
    _lastOtpError = null;
  }

  AuthNotifier(this._datasource, this._auditLogRepo, [this._emailService, this._pushService]) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    final user = _datasource.currentUser;
    if (user != null) {
      _loadProfile(user.id);
      _subscribeToProfileChanges(user.id);
      _pushService?.initialize().then((_) {
        _pushService?.registerDeviceToken();
      });
      _pushService?.listenToRealtimeNotifications(user.id);
    } else {
      state = const AsyncValue.data(null);
    }
  }

  void _subscribeToProfileChanges(String userId) {
    _profileChannel?.unsubscribe();
    try {
      _profileChannel = Supabase.instance.client
          .channel('public:profiles:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            callback: (payload) {
              // ignore: avoid_print
              print('⚡ [AuthNotifier] Realtime profile update detected for $userId: ${payload.newRecord}');
              _loadProfile(userId);
            },
          )
          .subscribe();
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ [AuthNotifier] Realtime profile subscription notice: $e');
    }
  }

  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadProfile(String userId) async {
    state = const AsyncValue.loading();
    try {
      var profile = await _datasource.fetchProfile(userId);
      if (profile == null) {
        // Fallback: create UserProfile from auth user metadata if database row is missing
        final user = _datasource.currentUser;
        if (user != null) {
          final metaRole = user.userMetadata?['role'] as String? ?? 'student';
          // Privileged roles are never auto-assigned from metadata: they require
          // an existing profiles row created by an admin appointment.
          if (metaRole == 'admin' || metaRole == 'tpo') {
            state = const AsyncValue.data(null);
            return;
          }
          final metaName = user.userMetadata?['name'] as String? ?? user.userMetadata?['full_name'] as String? ?? user.email?.split('@').first ?? 'User';
          profile = UserProfile(
            id: user.id,
            email: user.email ?? '',
            name: metaName,
            role: UserRole.fromString(metaRole),
            approvalStatus: metaRole == 'student' ? ApprovalStatus.pending : ApprovalStatus.approved,
            linkedinUrl: user.userMetadata?['linkedin_url'] as String?,
            githubUrl: user.userMetadata?['github_url'] as String?,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
      }
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _datasource.signInWithPassword(
        email: email,
        password: password,
      );
      final userId = response.user?.id;
      if (userId != null) {
        _pendingOtpEmail = null;
        _pendingPassword = null;
        _lastOtpError = null;
        await _loadProfile(userId);
        
        // Log the sign in action safely
        try {
          await _auditLogRepo.logAction(
            action: AuditAction.login,
            description: 'Logged in successfully.',
          );
        } catch (_) {}

        // Register FCM Push Token for logged in user safely
        try {
          await _pushService?.initialize();
          await _pushService?.registerDeviceToken();
          _pushService?.listenToRealtimeNotifications(userId);
        } catch (pushErr) {
          debugPrint('[AuthNotifier] Push registration notice: $pushErr');
        }
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? department,
    String? rollNumber,
  }) async {
    try {
      await _datasource.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        department: department,
        rollNumber: rollNumber,
      );
      _pendingOtpEmail = email;
      _pendingPassword = password;
      _lastOtpError = null;
      try {
        await _datasource.requestOtp(email: email, purpose: 'signup');
      } catch (e) {
        // Don't fail signup: the OTP screen exposes the error and a Resend
        // action, so the user can retry delivery without re-registering.
        _lastOtpError = e.toString();
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      _pendingOtpEmail = null;
      _pendingPassword = null;
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> resendOtp(String email) async {
    try {
      await _datasource.requestOtp(email: email, purpose: 'signup');
      _lastOtpError = null;
    } catch (e) {
      _lastOtpError = e.toString();
      rethrow;
    }
  }

  Future<void> verifySignupOtp({
    required String email,
    required String code,
  }) async {
    try {
      await _datasource.verifyOtp(email: email, code: code, purpose: 'signup');
      
      // If we have the signup password, sign in immediately so Supabase has an active session
      if (_pendingPassword != null) {
        try {
          final authRes = await _datasource.signInWithPassword(email: email, password: _pendingPassword!);
          if (authRes.user != null) {
            await _datasource.markEmailVerified(authRes.user!.id);
            _subscribeToProfileChanges(authRes.user!.id);
            await _loadProfile(authRes.user!.id);
            try {
              await _pushService?.initialize();
              await _pushService?.registerDeviceToken();
              _pushService?.listenToRealtimeNotifications(authRes.user!.id);
            } catch (pushErr) {
              debugPrint('[AuthNotifier] Push registration notice: $pushErr');
            }
            _pendingOtpEmail = null;
            _pendingPassword = null;
            _lastOtpError = null;
            return;
          }
        } catch (e) {
          debugPrint('[AuthNotifier] Auto sign-in notice: $e');
        }
      }

      _pendingOtpEmail = null;
      _pendingPassword = null;
      _lastOtpError = null;

      final user = _datasource.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client
              .from('profiles')
              .update({'email_verified': true, 'updated_at': DateTime.now().toIso8601String()})
              .eq('id', user.id);
        } catch (_) {}
        _subscribeToProfileChanges(user.id);
        
        final prof = await _datasource.fetchProfile(user.id);
        if (prof != null) {
          final map = Map<String, dynamic>.from(prof.toMap());
          map['email_verified'] = true;
          state = AsyncValue.data(UserProfile.fromMap(map));
        } else {
          await _loadProfile(user.id);
        }
      } else {
        // Look up by email from profiles table
        final profileMap = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('email', email)
            .maybeSingle();

        if (profileMap != null) {
          final map = Map<String, dynamic>.from(profileMap);
          map['email_verified'] = true;
          state = AsyncValue.data(UserProfile.fromMap(map));
        } else {
          final p = UserProfile(
            id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
            email: email,
            name: email.split('@').first,
            role: UserRole.student,
            emailVerified: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          state = AsyncValue.data(p);
        }
      }

      final currentProf = state.valueOrNull;
      if (currentProf != null && currentProf.email.isNotEmpty) {
        _emailService?.sendWelcomeEmail(
          recipientEmail: currentProf.email,
          studentName: currentProf.name,
          role: currentProf.role.displayName,
          department: currentProf.department ?? 'Computer Science and Engineering',
        );

        // Welcome push notification (best-effort; token may register shortly after)
        try {
          await Supabase.instance.client.functions.invoke('send-fcm-push', body: {
            'user_ids': [currentProf.id],
            'title': 'Welcome to Placement Connect',
            'body': 'Your account has been verified. Best of luck with your placements!',
          });
        } catch (_) {}
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async {
    await _datasource.verifyOtp(email: email, code: code, purpose: purpose);
  }

  Future<void> requestPasswordResetOtp(String email) async {
    final existing = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('email', email)
        .maybeSingle();
    if (existing == null) {
      throw Exception('No account found for this email.');
    }
    await _datasource.requestOtp(email: email, purpose: 'password_reset');
  }

  Future<void> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _datasource.resetPasswordWithOtp(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _pushService?.unregisterDeviceToken();
      await _datasource.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void refreshProfile(String userId) {
    _loadProfile(userId);
    _pushService?.initialize().then((_) {
      _pushService?.registerDeviceToken();
    });
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserProfile?>>((ref) {
  final datasource = ref.watch(authDatasourceProvider);
  final auditLogRepo = ref.watch(auditLogRepositoryProvider);
  final emailService = ref.watch(emailNotificationServiceProvider);
  final pushService = ref.watch(pushNotificationServiceProvider);
  return AuthNotifier(datasource, auditLogRepo, emailService, pushService);
});




