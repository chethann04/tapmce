import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/skeleton_loader.dart';
import '../../../../shared/presentation/widgets/app_logo.dart';
import '../../../../shared/presentation/widgets/app_refresh_indicator.dart';
import '../../../../shared/presentation/widgets/profile_avatar.dart';
import '../../../../shared/presentation/widgets/subtle_divider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _showAdminProfileModal(
    BuildContext context,
    WidgetRef ref,
    UserProfile user,
  ) async {
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
      builder: (ctx) {
        bool isUploading = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: brandTheme.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Stack(
                    children: [
                      ProfileAvatar(
                        imageUrl: user.photoUrl,
                        name: user.name,
                        size: ProfileAvatarSize.large,
                        showBorder: true,
                        borderColor: brandTheme.brassPrimary,
                        borderWidth: 2.5,
                        semanticsLabel: '${user.name} profile picture',
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final profileService = ref.read(profileServiceProvider);
                              try {
                                final bytes = await profileService.pickAndCropImage(context);
                                if (bytes == null) return;

                                setModalState(() => isUploading = true);
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
                                  userId: user.id,
                                  imageBytes: bytes,
                                );

                                if (ctx.mounted) Navigator.pop(ctx);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Profile photo updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Error updating photo: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                            customBorder: const CircleBorder(),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: brandTheme.brassGradient,
                                shape: BoxShape.circle,
                              ),
                              child: isUploading
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: brandTheme.onBrass,
                                      ),
                                    )
                                  : Icon(Icons.camera_alt_rounded, size: 14, color: brandTheme.onBrass),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: brandTheme.brassPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'SYSTEM ADMINISTRATOR',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: brandTheme.brassPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: brandTheme.cardBorder),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _modalInfoRow(Icons.email_outlined, 'Email', user.email, brandTheme),
                        const SubtleDivider(height: 16),
                        _modalInfoRow(Icons.apartment_rounded, 'Department', user.department ?? 'IT & Administration', brandTheme),
                        const SubtleDivider(height: 16),
                        _modalInfoRow(Icons.security_rounded, 'Access Level', 'Full System Superuser ✓', brandTheme, isAccent: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(authNotifierProvider.notifier).signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                      label: Text('Sign Out', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  static Widget _modalInfoRow(IconData icon, String label, String value, AppBrandTheme brandTheme, {bool isAccent = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isAccent ? brandTheme.brassPrimary : brandTheme.textMuted),
        const SizedBox(width: 10),
        Text('$label: ', style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAccent ? brandTheme.brassPrimary : null,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(authNotifierProvider);
    final user = profileAsync.valueOrNull;
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: AppLogo(size: 32),
        ),
        title: Text('System Administration', style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, size: 20, color: brandTheme.textMuted),
            tooltip: 'Sign Out',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _body(context, ref, profile?.fullName ?? 'Admin', brandTheme, theme, profile),
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.sp5),
          child: Column(
            children: [
              SkeletonCardRow(),
              SkeletonCardRow(),
            ],
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, String name, AppBrandTheme brandTheme, ThemeData theme, UserProfile? profile) => AppRefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminStatsProvider);
          await ref.read(adminStatsProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.sp5),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          text: 'System ',
                          style: GoogleFonts.fraunces(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          children: [
                            TextSpan(
                              text: 'Control',
                              style: GoogleFonts.fraunces(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: brandTheme.brassPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('User roles, security audit & database controls',
                          style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sp2),
                InkWell(
                  onTap: profile != null ? () => _showAdminProfileModal(context, ref, profile) : null,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: brandTheme.brassSoft,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text('Admin',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sp5),

            // Real-time Stats Header
            Consumer(
              builder: (context, ref, child) {
                final statsAsync = ref.watch(adminStatsProvider);
                return statsAsync.when(
                  data: (stats) => Row(
                    children: [
                      Expanded(child: _statCard('${stats.userCount}', 'Users', theme, brandTheme)),
                      const SizedBox(width: AppSpacing.sp3),
                      Expanded(child: _statCard('${stats.companyCount}', 'Companies', theme, brandTheme)),
                      const SizedBox(width: AppSpacing.sp3),
                      Expanded(child: _statCard('${stats.auditLogCount}', 'Audit Logs', theme, brandTheme)),
                    ],
                  ),
                  loading: () => Row(
                    children: [
                      Expanded(child: _statCard('...', 'Users', theme, brandTheme)),
                      const SizedBox(width: AppSpacing.sp3),
                      Expanded(child: _statCard('...', 'Companies', theme, brandTheme)),
                      const SizedBox(width: AppSpacing.sp3),
                      Expanded(child: _statCard('...', 'Audit Logs', theme, brandTheme)),
                    ],
                  ),
                  error: (_, __) => Row(
                    children: [
                      Expanded(child: _statCard('0', 'Users', theme, brandTheme)),
                      const SizedBox(width: AppSpacing.sp3),
                      Expanded(child: _statCard('0', 'Companies', theme, brandTheme)),
                      const SizedBox(width: AppSpacing.sp3),
                      Expanded(child: _statCard('0', 'Audit Logs', theme, brandTheme)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sp6),

            Text(
              'MANAGEMENT MODULES',
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.08,
                color: brandTheme.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.sp3),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSpacing.sp3,
              mainAxisSpacing: AppSpacing.sp3,
              mainAxisExtent: 118,
              children: [
                _card(Icons.school_rounded, 'UG Courses & Programs', brandTheme.brassPrimary, theme, brandTheme, onTap: () => context.push('/admin/courses')),
                _card(Icons.people_outline_rounded, 'Appoint TPO', brandTheme.brassPrimary, theme, brandTheme, onTap: () => context.push('/admin/appoint-tpo')),
                _card(Icons.verified_user_outlined, 'Appoint Faculty Coordinator', brandTheme.brassSoft, theme, brandTheme, onTap: () => context.push('/admin/appoint-fc')),
                _card(Icons.assessment_outlined, 'Compliance Reports', brandTheme.statusPending, theme, brandTheme, onTap: () => context.push('/admin/reports')),
                _card(Icons.security_rounded, 'Audit Logs', brandTheme.statusShortlisted, theme, brandTheme, onTap: () => context.push('/admin/audit-logs')),
                _card(Icons.settings_suggest_rounded, 'System Settings', brandTheme.brassA, theme, brandTheme, onTap: () => context.push('/admin/settings')),
              ],
            ),
          ],
        ),
      ),
    );

  Widget _statCard(String num, String label, ThemeData theme, AppBrandTheme brandTheme) => Container(
        padding: const EdgeInsets.all(AppSpacing.sp4),
        decoration: ShapeDecoration(
          color: theme.colorScheme.surface,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
            side: BorderSide(color: brandTheme.cardBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(num, style: GoogleFonts.ibmPlexMono(fontSize: 22, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: brandTheme.textMuted)),
          ],
        ),
      );

  Widget _card(IconData icon, String label, Color color, ThemeData theme, AppBrandTheme brandTheme, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        child: Container(
          decoration: ShapeDecoration(
            color: theme.colorScheme.surface,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
              side: BorderSide(color: brandTheme.cardBorder),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      );
}
