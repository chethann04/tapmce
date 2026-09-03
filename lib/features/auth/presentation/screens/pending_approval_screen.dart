import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../../../shared/presentation/widgets/app_logo.dart';

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userProfile = ref.watch(authNotifierProvider).valueOrNull;
    final isRejected = userProfile?.approvalStatus == ApprovalStatus.rejected;
    final rejectionReason = userProfile?.rejectionReason ?? 'Incorrect academic information or document issue.';

    return Scaffold(
      appBar: AppBar(
        title: Text(isRejected ? 'Verification Required' : 'Account Pending'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authNotifierProvider.notifier).signOut();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 84, showGlow: true),
              const SizedBox(height: 24),
              if (isRejected) ...[
                Text(
                  'Profile Verification Required',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Reason for Rejection:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade300,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rejectionReason,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 8),
                      Text(
                        '📢 Action Required:\nPlease meet your Department Faculty Coordinator to verify your official academic records and have your details corrected.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade200,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  'Awaiting Faculty Approval',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your profile details have been submitted and are currently in the verification queue of your Department Faculty Coordinator.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(authNotifierProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Status Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
