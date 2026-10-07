import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../../domain/entities/student_onboarding_data.dart';

/// Handles all Supabase calls for the student profile onboarding wizard.
class StudentProfileRemoteDatasource {
  final SupabaseClient _client;

  StudentProfileRemoteDatasource(this._client);

  /// Uploads a resume PDF to Supabase Storage and returns the public/signed URL.
  /// Path: resumes/{userId}/{fileName}
  Future<String?> uploadResume({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path = '$userId/$fileName';
    await _client.storage
        .from('resumes')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
    // Returns a signed URL valid for 10 years (resumes bucket is private)
    final signedUrl = await _client.storage
        .from('resumes')
        .createSignedUrl(path, 60 * 60 * 24 * 365 * 10);
    return signedUrl;
  }

  /// Uploads a profile photo to Supabase Storage and returns the public URL.
  /// Path: avatars/{userId}/{fileName}
  Future<String?> uploadPhoto({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path = '$userId/$fileName';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    // avatars bucket is public — return the public URL
    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    return publicUrl;
  }

  /// Saves all onboarding fields to the `profiles` table and sets
  /// `profile_completed = true`.
  Future<void> saveOnboardingProfile({
    required String userId,
    required StudentOnboardingData data,
    String? resumeUrl,
    String? photoUrl,
  }) async {
    final updateMap = <String, dynamic>{
      'name': data.fullName,
      'phone': data.phone,
      'dob': data.dob?.toIso8601String().split('T').first,
      'gender': data.gender,
      if (photoUrl != null && photoUrl.isNotEmpty) 'photo_url': photoUrl,
      'semester': data.semester,
      'section': data.section,
      'admission_year': data.admissionYear,
      'graduation_year': data.graduationYear,
      'tenth_percent': data.sslcPercent,
      'twelfth_or_diploma_percent': data.pucOrDiplomaPercent,
      'cgpa': data.cgpa,
      'active_backlogs': data.activeBacklogs,
      if (resumeUrl != null && resumeUrl.isNotEmpty) 'resume_url': resumeUrl,
      'linkedin_url': data.linkedinUrl,
      'github_url': data.githubUrl,
      'profile_completed': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (data.usn != null && data.usn!.isNotEmpty) {
      updateMap['usn'] = data.usn;
    }
    if (data.detectedCourseId != null) {
      updateMap['detected_course_id'] = data.detectedCourseId;
    }
    if (data.detectedCourseCode != null) {
      updateMap['detected_course_code'] = data.detectedCourseCode;
      updateMap['department'] = data.detectedCourseName;
    }
    if (data.detectedCourseName != null) {
      updateMap['detected_course_name'] = data.detectedCourseName;
    }

    // Save linkedin_url and github_url into Supabase Auth user_metadata so links
    // persist reliably even before migration 00043 is executed on the database.
    if (_client.auth.currentUser?.id == userId) {
      try {
        await _client.auth.updateUser(
          UserAttributes(
            data: {
              'linkedin_url': data.linkedinUrl ?? '',
              'github_url': data.githubUrl ?? '',
            },
          ),
        );
      } catch (authError) {
        // Non-blocking fallback; continue with database update
      }
    }

    try {
      // Deterministically UPDATE the existing profile by user ID (UUID)
      final existingRows = await _client
          .from('profiles')
          .update(updateMap)
          .eq('id', userId)
          .select('id');

      if ((existingRows as List).isEmpty) {
        // Fallback: only insert if row does not exist yet
        final currentUser = _client.auth.currentUser;
        final email = currentUser?.id == userId ? currentUser?.email : null;
        try {
          await _client.from('profiles').insert({
            'id': userId,
            if (email != null) 'email': email,
            'role': 'student',
            'approval_status': 'pending',
            'email_verified': true,
            ...updateMap,
          });
        } on PostgrestException catch (insertErr) {
          if (insertErr.code == '42703' ||
              insertErr.message.contains('linkedin_url') ||
              insertErr.message.contains('github_url')) {
            final legacyInsert = Map<String, dynamic>.from(updateMap)
              ..remove('linkedin_url')
              ..remove('github_url');
            await _client.from('profiles').insert({
              'id': userId,
              if (email != null) 'email': email,
              'role': 'student',
              'approval_status': 'pending',
              'email_verified': true,
              ...legacyInsert,
            });
          } else {
            rethrow;
          }
        }
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        if (e.message.contains('profiles_email_key')) {
          throw Exception('This email is already associated with another account.');
        } else if (e.message.contains('usn') || e.message.contains('profiles_usn_key')) {
          throw Exception('This USN is already registered with another account.');
        }
        throw Exception('Duplicate information detected. Please check your details.');
      }
      // If error is due to missing linkedin_url / github_url column, retry without them
      if (e.code == '42703' || e.message.contains('linkedin_url') || e.message.contains('github_url')) {
        final legacyMap = Map<String, dynamic>.from(updateMap)
          ..remove('linkedin_url')
          ..remove('github_url');
        await _client.from('profiles').update(legacyMap).eq('id', userId);
      } else {
        throw Exception('Unable to update profile: ${e.message}');
      }
    } catch (e) {
      if (e.toString().contains('23505') || e.toString().contains('profiles_email_key')) {
        throw Exception('This email is already associated with another account.');
      }
      rethrow;
    }

    // Notify Faculty Coordinator of this department for review
    try {
      final deptName = data.detectedCourseName;
      if (deptName != null && deptName.isNotEmpty) {
        final coordinators = await _client
            .from('profiles')
            .select('id')
            .eq('department', deptName)
            .filter('role', 'in', ['faculty', 'coordinator', 'faculty_coordinator']);
        final coordIds = (coordinators as List)
            .map((c) => c['id'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toList();

        if (coordIds.isNotEmpty) {
          final studentName = data.fullName.isNotEmpty ? data.fullName : 'A student';
          final usnStr = data.usn != null && data.usn!.isNotEmpty ? ' (${data.usn})' : '';
          for (final cId in coordIds) {
            await _client.from('notifications').insert({
              'recipient_id': cId,
              'title': '📋 New Student Verification Request',
              'message': '$studentName$usnStr submitted profile details for $deptName review.',
              'type': 'verification_request',
            });
          }
          await _client.functions.invoke('send-fcm-push', body: {
            'user_ids': coordIds,
            'title': '📋 New Student Verification Request',
            'body': '$studentName$usnStr submitted profile details for $deptName review.',
          });
        }
      }
    } catch (_) {}
  }
}



