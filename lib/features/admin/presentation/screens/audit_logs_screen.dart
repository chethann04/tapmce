import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../audit/domain/entities/audit_log_entry.dart';
import '../../../audit/presentation/providers/audit_log_provider.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  String _search = '';
  String _roleFilter = 'All';
  final _roles = ['All', 'Admin', 'TPO', 'Faculty', 'Student'];

  Color _actionColor(AuditAction a, BuildContext ctx) {
    switch (a) {
      case AuditAction.verification: return const Color(0xFF10B981);
      case AuditAction.driveCreated: return const Color(0xFF3B82F6);
      case AuditAction.optIn: return const Color(0xFF8B5CF6);
      case AuditAction.optOut: return Colors.orange;
      case AuditAction.login: return Colors.grey;
      case AuditAction.rejection: return const Color(0xFFEF4444);
      case AuditAction.roleChange: return const Color(0xFFB45309);
      case AuditAction.other: return Colors.grey;
    }
  }

  IconData _actionIcon(AuditAction a) {
    switch (a) {
      case AuditAction.verification: return Icons.verified_user_rounded;
      case AuditAction.driveCreated: return Icons.business_center_rounded;
      case AuditAction.optIn: return Icons.how_to_reg_rounded;
      case AuditAction.optOut: return Icons.person_remove_rounded;
      case AuditAction.login: return Icons.login_rounded;
      case AuditAction.rejection: return Icons.cancel_rounded;
      case AuditAction.roleChange: return Icons.admin_panel_settings_rounded;
      case AuditAction.other: return Icons.info_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  List<AuditLogEntry> _filtered(List<AuditLogEntry> logs) {
    return logs.where((e) {
      final matchRole = _roleFilter == 'All' || e.actorRole.toLowerCase() == _roleFilter.toLowerCase();
      final matchSearch = _search.isEmpty ||
          e.actorName.toLowerCase().contains(_search.toLowerCase()) ||
          e.description.toLowerCase().contains(_search.toLowerCase());
      return matchRole && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final auditLogsAsync = ref.watch(auditLogsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/admin');
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/admin');
              }
            },
          ),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Text('Audit Logs', style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📥 Audit log exported to CSV!'), behavior: SnackBarBehavior.floating),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + Filter bar
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by actor or action…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: brandTheme?.surfaceAlt ?? theme.colorScheme.surfaceContainerLowest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: brandTheme?.textMuted),
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _roles.map((role) {
                      final selected = _roleFilter == role;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(role, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : theme.colorScheme.onSurface)),
                          selected: selected,
                          selectedColor: brandTheme?.brassPrimary ?? theme.colorScheme.primary,
                          backgroundColor: brandTheme?.surfaceAlt,
                          onSelected: (_) => setState(() => _roleFilter = role),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Count label
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                auditLogsAsync.when(
                  data: (logs) => Text('${_filtered(logs).length} events', style: GoogleFonts.inter(fontSize: 12, color: brandTheme?.textMuted, fontWeight: FontWeight.w500)),
                  loading: () => Text('Loading...', style: GoogleFonts.inter(fontSize: 12, color: brandTheme?.textMuted, fontWeight: FontWeight.w500)),
                  error: (_, __) => Text('Error', style: GoogleFonts.inter(fontSize: 12, color: brandTheme?.textMuted, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          // Log list
          Expanded(
            child: auditLogsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e', style: GoogleFonts.inter(color: Colors.red))),
              data: (logs) {
                final filteredLogs = _filtered(logs);
                return filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: brandTheme?.textMuted),
                            const SizedBox(height: 12),
                            Text('No logs found', style: GoogleFonts.inter(color: brandTheme?.textMuted)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: filteredLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final log = filteredLogs[i];
                          final color = _actionColor(log.action, context);
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: brandTheme?.cardBorder ?? theme.colorScheme.outline),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                                  child: Icon(_actionIcon(log.action), color: color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(log.actorName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                                          ),
                                          Text(_timeAgo(log.timestamp), style: GoogleFonts.inter(fontSize: 11, color: brandTheme?.textMuted)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(4)),
                                        child: Text(log.actorRole, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(log.description, style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface, height: 1.4)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
              },
            ),
          ),
        ],
      ),
      ),
    );
  }
}

