import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(Supabase.instance.client, ref);
});

class ProfileService {
  final SupabaseClient _supabase;
  final Ref _ref;

  ProfileService(this._supabase, this._ref);

  /// Prompts the user to select an image from Camera or Gallery and crop it 1:1.
  Future<Uint8List?> pickAndCropImage(BuildContext context) async {
    final theme = Theme.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Select Profile Photo',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.photo_library_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                title: Text('Choose from Gallery', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: theme.colorScheme.primary, size: 20),
                ),
                title: Text('Take a Photo', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (picked == null) return null;

    CroppedFile? croppedFile;
    try {
      croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: theme.colorScheme.surface,
            toolbarWidgetColor: theme.colorScheme.onSurface,
            statusBarLight: theme.brightness == Brightness.dark,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );
    } catch (_) {
      // If cropper fails on some platforms, use raw image bytes directly
    }

    if (croppedFile != null) {
      return await croppedFile.readAsBytes();
    }
    return await picked.readAsBytes();
  }

  /// Uploads avatar binary to Supabase Storage `avatars` bucket, updates `profiles.photo_url`,
  /// and invalidates auth notifier state so the entire application updates instantly.
  Future<String> uploadAndUpdateAvatar({
    required String userId,
    required Uint8List imageBytes,
    String fileExt = 'jpg',
  }) async {
    // 1. Validation (5MB max)
    if (imageBytes.lengthInBytes > 5 * 1024 * 1024) {
      throw Exception('Image file is too large. Maximum allowed size is 5MB.');
    }

    // 2. Upload to avatars bucket
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/avatar_$timestamp.$fileExt';

    await _supabase.storage.from('avatars').uploadBinary(
          path,
          imageBytes,
          fileOptions: FileOptions(
            contentType: 'image/$fileExt',
            upsert: true,
          ),
        );

    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);

    // 3. Update profiles table
    await _supabase.from('profiles').update({
      'photo_url': publicUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    // 4. Invalidate Riverpod auth cache
    _ref.invalidate(currentProfileProvider);
    _ref.invalidate(authNotifierProvider);

    return publicUrl;
  }

  /// Updates basic profile info (name, phone, department) for the current user.
  Future<void> updateProfileDetails({
    required String userId,
    String? name,
    String? phone,
    String? department,
  }) async {
    final updateMap = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null && name.trim().isNotEmpty) {
      updateMap['name'] = name.trim();
    }
    if (phone != null) {
      updateMap['phone'] = phone.trim();
    }
    if (department != null && department.trim().isNotEmpty) {
      updateMap['department'] = department.trim();
    }

    await _supabase.from('profiles').update(updateMap).eq('id', userId);

    // Invalidate Riverpod auth cache
    _ref.invalidate(currentProfileProvider);
    _ref.invalidate(authNotifierProvider);
  }
}
