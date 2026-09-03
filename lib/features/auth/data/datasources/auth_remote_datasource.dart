import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:placement_connect/core/utils/usn_parser.dart';
import '../../domain/entities/user_profile.dart';

class AuthRemoteDatasource {
  final SupabaseClient _client;

  AuthRemoteDatasource(this._client);

  // ── Auth State Stream ─────────────────────────────────────────────────────
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  // ── Sign In (OTP / Magic Link) ─────────────────────────────────────────────
  Future<void> signInWithOtp(String email) async {
    await _client.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
    );
  }

  // ── Sign Up ───────────────────────────────────────────────────────────────
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? department,
    String? rollNumber,
  }) async {
    // If department is null but USN is provided, derive department from USN branch code
    String? resolvedDept = department;
    if ((resolvedDept == null || resolvedDept.isEmpty) && rollNumber != null && rollNumber.isNotEmpty) {
      final code = UsnParser.extractBranchCode(rollNumber);
      if (code != null) {
        switch (code.toUpperCase()) {
          case 'IS':
            resolvedDept = 'Information Science Engineering';
            break;
          case 'CS':
            resolvedDept = 'Computer Science Engineering';
            break;
          case 'EC':
            resolvedDept = 'Electronics & Communication Engineering';
            break;
          case 'EE':
            resolvedDept = 'Electrical & Electronics Engineering';
            break;
          case 'ME':
            resolvedDept = 'Mechanical Engineering';
            break;
          case 'CV':
            resolvedDept = 'Civil Engineering';
            break;
          default:
            resolvedDept = code;
        }
      }
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': fullName,
        'full_name': fullName,
        'role': role,
        if (resolvedDept != null) 'department': resolvedDept,
        if (rollNumber != null) 'usn': rollNumber,
      },
    );

    final user = response.user;
    if (user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'email': email,
          'name': fullName,
          'role': role,
          if (resolvedDept != null) 'department': resolvedDept,
          if (rollNumber != null) 'usn': rollNumber,
          'approval_status': role == 'student' ? 'pending' : 'approved',
        });
      } catch (e) {
        // Silently ignore upsert errors here, AuthNotifier handles fallback
      }
    }

    return response;
  }

  // ── Sign In with Password ─────────────────────────────────────────────────
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ── Custom OTP (edge function, SMTP-delivered) ───────────────────────────
  /// Requests a 6-digit verification code, emailed via the send-otp edge
  /// function (which delivers through SMTP so college mailboxes accept it).
  Future<void> requestOtp({
    required String email,
    required String purpose,
  }) async {
    final res = await _client.functions.invoke('send-otp', body: {
      'action': 'send',
      'email': email,
      'purpose': purpose,
    });
    final data = res.data is Map ? res.data as Map : {};
    if (res.status >= 400 || data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'Failed to send verification code.');
    }
  }

  // ── Verify OTP ────────────────────────────────────────────────────────────
  Future<void> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async {
    final res = await _client.functions.invoke('send-otp', body: {
      'action': 'verify',
      'email': email,
      'code': code,
      'purpose': purpose,
    });
    final data = res.data is Map ? res.data as Map : {};
    if (res.status >= 400 || data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'Verification failed.');
    }
  }

  /// Records that the user completed email OTP verification.
  Future<void> markEmailVerified(String userId) async {
    await _client.from('profiles').update({'email_verified': true}).eq('id', userId);
  }

  /// Verifies a password-reset OTP and sets a new password server-side
  /// (works without an active session via the edge function).
  Future<void> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final res = await _client.functions.invoke('send-otp', body: {
      'action': 'reset_password',
      'email': email,
      'code': code,
      'purpose': 'password_reset',
      'newPassword': newPassword,
    });
    final data = res.data is Map ? res.data as Map : {};
    if (res.status >= 400 || data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'Password reset failed.');
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Fetch Profile ─────────────────────────────────────────────────────────
  Future<UserProfile?> fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        return UserProfile.fromMap(data);
      }
    } catch (e) {
      // Log error — do NOT silently swallow and fall back to student
      debugPrint('[fetchProfile] DB fetch failed for $userId: $e');
    }

    // Fallback: read role from auth metadata only — never default to student
    final user = currentUser;
    if (user != null && user.id == userId) {
      final email = user.email ?? '';
      final metaRole = user.userMetadata?['role'] as String?;
      final metaName = user.userMetadata?['name'] as String?
          ?? user.userMetadata?['full_name'] as String?
          ?? email.split('@').first;

      // Determine role from metadata or email domain — NO student fallback.
      // Privileged roles (admin/tpo) are NEVER guessed from email: they require
      // an existing `profiles` row created by an admin appointment.
      UserRole role;
      if (metaRole != null && metaRole.isNotEmpty) {
        try {
          role = UserRole.fromString(metaRole);
        } catch (_) {
          debugPrint('[fetchProfile] Unknown metaRole "$metaRole" for $email. Returning null.');
          return null;
        }
        if (role == UserRole.admin || role == UserRole.tpo) {
          debugPrint(
              '[fetchProfile] Privileged role "$metaRole" for $email has no profiles row. '
              'Refusing to auto-assign. Returning null.');
          return null;
        }
      } else if (email.endsWith('@mcehassan.ac.in')) {
        // Faculty role — coordinator/TPO status is granted later by appointment
        role = UserRole.faculty;
      } else {
        // All other emails default to student role
        role = UserRole.student;
      }

      return UserProfile(
        id: userId,
        role: role,
        name: metaName,
        email: email,
        approvalStatus: role == UserRole.student
            ? ApprovalStatus.pending
            : ApprovalStatus.approved,
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    return null;
  }
}
