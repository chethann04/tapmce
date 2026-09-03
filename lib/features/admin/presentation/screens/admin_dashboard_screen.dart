import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/skeleton_loader.dart';
import '../../../../shared/presentation/widgets/app_logo.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(authNotifierProvider);
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
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) => _body(context, profile?.fullName ?? 'Admin', brandTheme, theme),
        loading: () => Padding(
          padding: const EdgeInsets.all(AppSpacing.sp5),
          child: Column(
            children: const [
              SkeletonCardRow(),
              SkeletonCardRow(),
            ],
          ),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _body(BuildContext context, String name, AppBrandTheme brandTheme, ThemeData theme) => SingleChildScrollView(
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandTheme.brassSoft,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Admin',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: brandTheme.brassPrimary)),
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
