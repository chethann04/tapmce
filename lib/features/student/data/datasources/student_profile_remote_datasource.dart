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
      'photo_url': photoUrl,
      'semester': data.semester,
      'section': data.section,
      'admission_year': data.admissionYear,
      'graduation_year': data.graduationYear,
      'tenth_percent': data.sslcPercent,
      'twelfth_or_diploma_percent': data.pucOrDiplomaPercent,
      'cgpa': data.cgpa,
      'active_backlogs': data.activeBacklogs,
      'resume_url': resumeUrl,
      'profile_completed': true,
      'email_verified': true,
      'id': userId,
        'email': Supabase.instance.client.auth.currentUser?.email,
      'role': 'student',
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

    await _client.from('profiles').upsert(updateMap);
  }
}



