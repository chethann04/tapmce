import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../shared/presentation/widgets/app_refresh_indicator.dart';
import '../../../../shared/presentation/widgets/profile_avatar.dart';
import '../../../../shared/presentation/widgets/subtle_divider.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class TpoProfileScreen extends ConsumerStatefulWidget {
  final UserProfile? profile;
  const TpoProfileScreen({super.key, this.profile});

  @override
  ConsumerState<TpoProfileScreen> createState() => _TpoProfileScreenState();
}

class _TpoProfileScreenState extends ConsumerState<TpoProfileScreen> {
  bool _isUploadingPhoto = false;

  Future<void> _changeProfilePhoto(BuildContext context, String userId) async {
    if (_isUploadingPhoto) return;
    final profileService = ref.read(profileServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final bytes = await profileService.pickAndCropImage(context);
      if (bytes == null) return;

      setState(() => _isUploadingPhoto = true);

      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Uploading profile photo...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      await profileService.uploadAndUpdateAvatar(
        userId: userId,
        imageBytes: bytes,
      );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ Profile photo updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ Error updating profile photo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _showEditDetailsModal(BuildContext context, UserProfile user) async {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phone ?? '');
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: brandTheme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit Profile Details',
              style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Update your display name and contact phone number.',
              style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Contact Phone Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final newName = nameController.text.trim();
                      final newPhone = phoneController.text.trim();
                      if (newName.isEmpty) return;

                      Navigator.pop(ctx);
                      try {
                        await ref.read(profileServiceProvider).updateProfileDetails(
                              userId: user.id,
                              name: newName,
                              phone: newPhone.isNotEmpty ? newPhone : null,
                            );
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('✅ Profile updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('❌ Error saving profile: $e'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: brandTheme.brassPrimary,
                      foregroundColor: brandTheme.onBrass,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(authNotifierProvider);
    final user = widget.profile ?? profileAsync.valueOrNull;
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final name = user?.fullName ?? 'TPO Officer';
    final email = user?.email ?? 'tpo@mcehassan.ac.in';
    final phone = user?.phone ?? '';
    final dept = user?.department?.isNotEmpty == true
        ? user!.department!
        : 'Training & Placement Cell';

    final topPadding = MediaQuery.of(context).padding.top + AppSpacing.sp4;

    return AppRefreshIndicator(
      onRefresh: () async {
        ref.invalidate(currentProfileProvider);
        ref.invalidate(authNotifierProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: topPadding,
          left: AppSpacing.sp5,
          right: AppSpacing.sp5,
          bottom: 140,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Profile Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sp5),
              decoration: ShapeDecoration(
                color: theme.colorScheme.surface,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(AppShapes.radiusHero),
                  side: BorderSide(color: brandTheme.cardBorder),
                ),
                shadows: brandTheme.shadow2,
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      ProfileAvatar(
                        imageUrl: user?.photoUrl,
                        name: name,
                        size: ProfileAvatarSize.hero,
                        showBorder: true,
                        borderColor: brandTheme.brassPrimary,
                        borderWidth: 3,
                        semanticsLabel: '$name profile picture',
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: user != null
                                ? () => _changeProfilePhoto(context, user.id)
                                : null,
                            customBorder: const CircleBorder(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: brandTheme.brassGradient,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _isUploadingPhoto
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: brandTheme.onBrass,
                                      ),
                                    )
                                  : Icon(Icons.camera_alt_rounded,
                                      size: 16, color: brandTheme.onBrass),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sp3),
                  Text(
                    name,
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandTheme.brassPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: brandTheme.brassPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'TRAINING & PLACEMENT OFFICER',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: brandTheme.brassPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sp4),
                  OutlinedButton.icon(
                    onPressed: user != null
                        ? () => _showEditDetailsModal(context, user)
                        : null,
                    icon: Icon(Icons.edit_outlined, size: 16, color: brandTheme.brassPrimary),
                    label: Text(
                      'Edit Details',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: brandTheme.brassPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: brandTheme.brassPrimary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sp5),
            Text(
              'Officer Information',
              style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sp3),

            // Profile Details List
            Container(
              decoration: ShapeDecoration(
                color: theme.colorScheme.surface,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                  side: BorderSide(color: brandTheme.cardBorder),
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.sp4),
              child: Column(
                children: [
                  _infoTile(Icons.person_outline_rounded, 'Full Name', name, brandTheme),
                  const SubtleDivider(height: 20),
                  _infoTile(Icons.apartment_rounded, 'Department / Cell', dept, brandTheme),
                  const SubtleDivider(height: 20),
                  _infoTile(Icons.email_outlined, 'Official Email', email, brandTheme),
                  const SubtleDivider(height: 20),
                  _infoTile(
                    Icons.phone_outlined,
                    'Contact Phone',
                    phone.isNotEmpty ? phone : 'Not specified (Tap edit to add)',
                    brandTheme,
                  ),
                  const SubtleDivider(height: 20),
                  _infoTile(Icons.verified_user_outlined, 'Assigned Role', 'TPO Officer', brandTheme),
                  const SubtleDivider(height: 20),
                  _infoTile(
                    Icons.security_rounded,
                    'Institution Access',
                    'Authorized Administrator ✓',
                    brandTheme,
                    isAccent: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sp5),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                label: Text(
                  'Sign Out',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, AppBrandTheme brandTheme, {bool isAccent = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isAccent ? brandTheme.brassPrimary : brandTheme.textMuted).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: isAccent ? brandTheme.brassPrimary : brandTheme.textMuted),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted)),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isAccent ? brandTheme.brassPrimary : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
