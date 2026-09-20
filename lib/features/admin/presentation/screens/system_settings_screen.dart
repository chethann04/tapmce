import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../shared/presentation/widgets/subtle_divider.dart';
import '../../domain/entities/department.dart';
import '../providers/departments_provider.dart';
import '../../../../core/services/email_notification_service.dart';
import '../../../../core/services/push_notification_service.dart';

class SystemSettingsScreen extends ConsumerStatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  ConsumerState<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends ConsumerState<SystemSettingsScreen> {
  // Academic Configuration
  String _activeYear = '2025-26';
  String _activeBatch = '2026';

  // Placement Policy Toggles
  bool _allowMultipleOffers = false;
  bool _requireFacultyApproval = true;
  bool _consentMandatory = true;
  bool _autoNotifyStudents = true;
  bool _maintenanceMode = false;

  // CGPA & Criteria
  final _defaultCgpaController = TextEditingController(text: '7.0');
  final _maxBacklogsController = TextEditingController(text: '0');

  bool _isSaving = false;

  @override
  void dispose() {
    _defaultCgpaController.dispose();
    _maxBacklogsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final res = await Supabase.instance.client
          .from('system_settings')
          .select()
          .eq('id', 'global_config')
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _activeYear = (res['active_academic_year'] as String?) ?? '2025-26';
          _activeBatch = (res['graduating_batch'] as String?) ?? '2026';
          _allowMultipleOffers = (res['allow_multiple_offers'] as bool?) ?? false;
          _requireFacultyApproval = (res['require_faculty_approval'] as bool?) ?? true;
          _consentMandatory = (res['consent_form_mandatory'] as bool?) ?? true;
          _autoNotifyStudents = (res['auto_notify_students'] as bool?) ?? true;
          _defaultCgpaController.text = (res['default_cgpa']?.toString()) ?? '7.0';
          _maxBacklogsController.text = (res['max_backlogs']?.toString()) ?? '0';
        });
      }
    } catch (_) {}
  }

  void _save() async {
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('system_settings').upsert({
        'id': 'global_config',
        'active_academic_year': _activeYear,
        'graduating_batch': _activeBatch,
        'allow_multiple_offers': _allowMultipleOffers,
        'require_faculty_approval': _requireFacultyApproval,
        'consent_form_mandatory': _consentMandatory,
        'auto_notify_students': _autoNotifyStudents,
        'default_cgpa': double.tryParse(_defaultCgpaController.text.trim()) ?? 7.0,
        'max_backlogs': int.tryParse(_maxBacklogsController.text.trim()) ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
        if (userId != null) 'updated_by': userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Placement policy & system settings saved!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteDepartment(Department dept) async {
    try {
      final repo = ref.read(departmentsRepositoryProvider);
      await repo.delete(dept.id);
      ref.invalidate(departmentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted department ${dept.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting department: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final accent = brandTheme?.brassPrimary ?? theme.colorScheme.primary;

    final deptsAsync = ref.watch(departmentsProvider);

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
          title: Text('System Settings', style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: accent, padding: const EdgeInsets.symmetric(horizontal: 18)),
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Section 1: Academic Year ───
          _sectionHeader('🎓 Academic Configuration', theme, brandTheme),
          const SizedBox(height: 10),
          _card(theme, brandTheme, [
            _settingRow(
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF3B82F6),
              title: 'Active Academic Year',
              subtitle: 'Students and drives are scoped to this year.',
              trailing: DropdownButton<String>(
                value: _activeYear,
                underline: const SizedBox(),
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                items: ['2024-25', '2025-26', '2026-27'].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                onChanged: (v) => setState(() => _activeYear = v!),
              ),
            ),
            const SubtleDivider(height: 1),
            _settingRow(
              icon: Icons.school_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'Graduating Batch',
              subtitle: 'Students of this batch are eligible for drives.',
              trailing: DropdownButton<String>(
                value: _activeBatch,
                underline: const SizedBox(),
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                items: ['2025', '2026', '2027'].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                onChanged: (v) => setState(() => _activeBatch = v!),
              ),
            ),
          ]),

          const SizedBox(height: 20),

          // ─── Section 2: Placement Policy ───
          _sectionHeader('📋 Placement Policy', theme, brandTheme),
          const SizedBox(height: 10),
          _card(theme, brandTheme, [
            _toggleRow(
              icon: Icons.work_history_rounded,
              color: const Color(0xFF10B981),
              title: 'Allow Multiple Offers',
              subtitle: 'If off, students placed in one company are auto-blocked from others.',
              value: _allowMultipleOffers,
              onChanged: (v) => setState(() => _allowMultipleOffers = v),
              accent: accent,
            ),
            const SubtleDivider(height: 1),
            _toggleRow(
              icon: Icons.verified_user_rounded,
              color: const Color(0xFF3B82F6),
              title: 'Require Faculty Approval',
              subtitle: 'Students must be verified by faculty before applying.',
              value: _requireFacultyApproval,
              onChanged: (v) => setState(() => _requireFacultyApproval = v),
              accent: accent,
            ),
            const SubtleDivider(height: 1),
            _toggleRow(
              icon: Icons.how_to_vote_rounded,
              color: const Color(0xFFB45309),
              title: 'Consent Form Mandatory',
              subtitle: 'Students must submit consent before applying to any drive.',
              value: _consentMandatory,
              onChanged: (v) => setState(() => _consentMandatory = v),
              accent: accent,
            ),
            const SubtleDivider(height: 1),
            _toggleRow(
              icon: Icons.notifications_active_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'Auto-notify Students',
              subtitle: 'Push notifications for new drives and status updates.',
              value: _autoNotifyStudents,
              onChanged: (v) => setState(() => _autoNotifyStudents = v),
              accent: accent,
            ),
          ]),

          const SizedBox(height: 20),

          // ─── Section: Email System Testing Suite ───
          _sectionHeader('✉️ Email Notification System Tester', theme, brandTheme),
          const SizedBox(height: 10),
          if (brandTheme != null)
            _card(theme, brandTheme, [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: brandTheme.brassPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.mark_email_read_rounded, color: brandTheme.brassPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dispatch Email Tests', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Send test emails for Welcome, Faculty Appt, Application, Attendance, Status & Offers.', style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandTheme.brassPrimary,
                        foregroundColor: brandTheme.onBrass,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _showEmailTesterDialog(context, brandTheme),
                      child: Text('Test', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ]),

          const SizedBox(height: 20),

          // ─── Section: FCM Push Notification Testing Suite ───
          _sectionHeader('🔔 FCM Push Notification Tester', theme, brandTheme),
          const SizedBox(height: 10),
          if (brandTheme != null)
            _card(theme, brandTheme, [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Test Push Notification Pipeline', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Verify Firebase token, device registration, and trigger instant test push alert.', style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _showPushTesterDialog(context, brandTheme),
                      child: Text('Test Push', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ]),

          const SizedBox(height: 20),

          // ─── Section 3: Departments with Branch Codes ───
          _sectionHeader('🏛️ Departments & USN Branch Mapping', theme, brandTheme),
          const SizedBox(height: 10),
          deptsAsync.when(
            loading: () => _card(theme, brandTheme, [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ]),
            error: (err, _) => _card(theme, brandTheme, [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading departments: $err', style: const TextStyle(color: Colors.red)),
              ),
            ]),
            data: (departments) => _card(theme, brandTheme, [
              if (departments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No departments registered.'),
                )
              else
                ...departments.asMap().entries.map((e) {
                  final dept = e.value;
                  final isLast = e.key == departments.length - 1;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                dept.branchCode,
                                style: GoogleFonts.ibmPlexMono(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                dept.name,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade300),
                              onPressed: () => _deleteDepartment(dept),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) const SubtleDivider(height: 1),
                    ],
                  );
                }),
              const SubtleDivider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: () => _showAddDeptDialog(context, accent),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Add Department', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 20),

          // ─── Section 5: Danger Zone ───
          _sectionHeader('⚠️ Danger Zone', theme, brandTheme),
          const SizedBox(height: 10),
          _card(theme, brandTheme, [
            _toggleRow(
              icon: Icons.construction_rounded,
              color: Colors.red,
              title: 'Maintenance Mode',
              subtitle: 'Locks all student and faculty access. Only admins can log in.',
              value: _maintenanceMode,
              onChanged: (v) {
                if (v) {
                  _showMaintenanceConfirm(context, accent, () => setState(() => _maintenanceMode = true));
                } else {
                  setState(() => _maintenanceMode = false);
                }
              },
              accent: Colors.red,
              isDestructive: true,
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
      ),
    );
  }

  Widget _sectionHeader(String label, ThemeData theme, AppBrandTheme? brandTheme) => Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: brandTheme?.textMuted, letterSpacing: 0.6),
      );

  Widget _card(ThemeData theme, AppBrandTheme? brandTheme, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brandTheme?.cardBorder ?? theme.colorScheme.outline),
        ),
        child: Column(children: children),
      );

  Widget _settingRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      );

  Widget _toggleRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color accent,
    bool isDestructive = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: isDestructive ? Colors.red : null)),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: isDestructive ? Colors.red : accent,
            ),
          ],
        ),
      );

  void _showAddDeptDialog(BuildContext context, Color accent) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Department', style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Department Name',
                  hintText: 'e.g. Civil Engineering',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Branch Code (USN Segment)',
                  hintText: 'e.g. CV',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (v.trim().length < 2 || v.trim().length > 4) return '2-4 chars';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final repo = ref.read(departmentsRepositoryProvider);
                try {
                  await repo.create(
                    name: nameCtrl.text.trim(),
                    branchCode: codeCtrl.text.trim(),
                  );
                  ref.invalidate(departmentsProvider);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating department: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEmailTesterDialog(BuildContext context, AppBrandTheme brandTheme) {
    final emailCtrl = TextEditingController(text: 'test@example.com');
    final emailService = ref.read(emailNotificationServiceProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('✉️ Email Notification Test Suite', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Recipient Email',
                  hintText: 'Enter destination email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠️ Please enter a valid recipient email address first!')),
                        );
                        return;
                      }
                      emailService.sendWelcomeEmail(
                        recipientEmail: email,
                        studentName: 'Test Student',
                        role: 'Student',
                        department: 'CSE',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Welcome email test dispatched to $email!')));
                    },
                    child: const Text('Welcome'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠️ Please enter a valid recipient email address first!')),
                        );
                        return;
                      }
                      emailService.sendFacultyAppointmentEmail(
                        recipientEmail: email,
                        facultyName: 'Dr. Smith',
                        department: 'CSE',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Faculty Appt email test dispatched to $email!')));
                    },
                    child: const Text('Faculty Appt'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠️ Please enter a valid recipient email address first!')),
                        );
                        return;
                      }
                      emailService.sendApplicationSubmittedEmail(
                        recipientEmail: email,
                        studentName: 'Test Student',
                        companyName: 'Acme Corp',
                        roleTitle: 'Software Engineer',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Application email test dispatched to $email!')));
                    },
                    child: const Text('Application'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠️ Please enter a valid recipient email address first!')),
                        );
                        return;
                      }
                      emailService.sendAttendanceConfirmationEmail(
                        recipientEmail: email,
                        companyName: 'Acme Corp',
                        date: '2026-08-01',
                        time: '10:00 AM',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance email test dispatched to $email!')));
                    },
                    child: const Text('Attendance'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠️ Please enter a valid recipient email address first!')),
                        );
                        return;
                      }
                      emailService.sendRoundQualifiedEmail(
                        recipientEmail: email,
                        studentName: 'Test Student',
                        companyName: 'Acme Corp',
                        qualifiedRound: 'Online Test',
                        nextRoundName: 'Technical Interview',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Qualified email test dispatched to $email!')));
                    },
                    child: const Text('Qualified'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠️ Please enter a valid recipient email address first!')),
                        );
                        return;
                      }
                      emailService.sendRoundRejectedEmail(
                        recipientEmail: email,
                        studentName: 'Test Student',
                        companyName: 'Acme Corp',
                        rejectedRound: 'Technical Interview',
                        remarks: 'Keep applying for future drives.',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rejected email test dispatched to $email!')));
                    },
                    child: const Text('Rejected'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠️ Please enter a valid recipient email address first!')),
                        );
                        return;
                      }
                      emailService.sendOfferReleasedEmail(
                        recipientEmail: email,
                        studentName: 'Test Student',
                        companyName: 'Acme Corp',
                        roleTitle: 'Software Engineer',
                        package: '12 LPA',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Offer email test dispatched to $email!')));
                    },
                    child: const Text('Offer Released'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠️ Please enter a valid recipient email address first!')),
                        );
                        return;
                      }
                      emailService.sendReminderEmail(
                        recipientEmail: email,
                        studentName: 'Test Student',
                        reminderTitle: 'Resume Upload Pending',
                        message: 'Please upload your latest resume to apply for upcoming drives.',
                        deadline: 'Tomorrow 5:00 PM',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder email test dispatched to $email!')));
                    },
                    child: const Text('Reminder'),
                  ),
                ],
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _diagRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isError ? Colors.redAccent : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPushTesterDialog(BuildContext context, AppBrandTheme brandTheme) {
    showDialog(
      context: context,
      builder: (ctx) {
        String testStatus = 'Ready to test push notification pipeline.';
        bool isTesting = false;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF8B5CF6), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Push Notification Tester',
                      style: GoogleFonts.fraunces(fontWeight: FontWeight.w600, fontSize: 17, color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live FCM push diagnostic & testing suite. Traces pipeline from token to Google FCM HTTP v1.',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      // Phase 18 Diagnostic Grid
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Consumer(
                          builder: (context, ref, _) {
                            final push = ref.watch(pushNotificationServiceProvider);
                            final currentUser = Supabase.instance.client.auth.currentUser;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🔍 PIPELINE DIAGNOSTICS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6))),
                                const SizedBox(height: 8),
                                _diagRow('Firebase Initialized:', push.isFirebaseInitialized ? 'YES ✅' : 'NO ❌'),
                                _diagRow('Notification Permission:', push.permissionStatus.toUpperCase()),
                                _diagRow('FCM Token Available:', push.currentFcmToken != null ? 'YES (${push.tokenLength} chars)' : 'MISSING ❌'),
                                _diagRow('Token Prefix:', push.tokenPrefix ?? 'None'),
                                _diagRow('Token in Supabase DB:', push.isTokenStoredInSupabase ? 'YES ✅' : 'NOT VERIFIED ⚠️'),
                                _diagRow('Current Auth User:', currentUser != null ? '${currentUser.id.substring(0, 8)}...' : 'NOT LOGGED IN'),
                                _diagRow('Notification Channel:', push.hasNotificationChannel ? 'EXISTS (high_importance)' : 'CHECKING'),
                                _diagRow('Last onMessage Received:', push.lastFcmOnMessage ?? 'NEVER'),
                                if (push.lastFcmError != null)
                                  _diagRow('Last Error:', push.lastFcmError!, isError: true),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Console Log / Response:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                            const SizedBox(height: 4),
                            SelectableText(
                              testStatus,
                              style: GoogleFonts.ibmPlexMono(fontSize: 10, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () async {
                                final pushService = ref.read(pushNotificationServiceProvider);
                                setDialogState(() => testStatus = 'Requesting permissions...');
                                final perm = await pushService.requestPermission();
                                setDialogState(() => testStatus = 'Permission: ${perm.authorizationStatus.name}');
                              },
                              icon: const Icon(Icons.security_rounded, size: 14),
                              label: const Text('Permission', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () async {
                                final pushService = ref.read(pushNotificationServiceProvider);
                                setDialogState(() => testStatus = 'Resetting cache & fetching fresh token for tapmce-30c3f...');
                                final newToken = await pushService.refreshToken();
                                final inDb = await pushService.checkTokenInDatabase();
                                setDialogState(() => testStatus = newToken != null
                                    ? '✅ Fresh Token Acquired!\nToken: ${pushService.tokenPrefix}\nVerified in Supabase DB: $inDb'
                                    : '❌ Failed to get fresh token: ${pushService.lastFcmError}');
                              },
                              icon: const Icon(Icons.sync_rounded, size: 14),
                              label: const Text('Refresh Token', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Instant OS Notification Banner Test (Direct Hardware Verification)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () async {
                            final pushService = ref.read(pushNotificationServiceProvider);
                            setDialogState(() => testStatus = 'Triggering local heads-up notification on device...');
                            await pushService.showLocalNotification(
                              title: '🚀 MCE Placement Connect [Instant Test]',
                              body: 'Heads-up notification channel & sound verified on this device!',
                              payload: 'test_drive_123',
                            );
                            setDialogState(() => testStatus = '✅ Heads-up notification sent to Android notification bar!');
                          },
                          icon: const Icon(Icons.notifications_active_rounded, size: 16),
                          label: Text(
                            'Test OS Notification Banner (Instant) 📱',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Phase 14: Raw Single-Token Push Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF38BDF8)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: isTesting
                              ? null
                              : () async {
                                  final pushService = ref.read(pushNotificationServiceProvider);
                                  final token = await pushService.getToken();
                                  if (token == null) {
                                    setDialogState(() => testStatus = '❌ Cannot send raw push: Device token is null.');
                                    return;
                                  }
                                  setDialogState(() {
                                    isTesting = true;
                                    testStatus = '⚡ [Phase 14] Dispatching RAW single-token push directly to device token...';
                                  });
                                  final res = await pushService.sendRawTokenPushTest(token: token);
                                  setDialogState(() {
                                    isTesting = false;
                                    testStatus = res['success'] == true
                                        ? '✅ Raw push SUCCESS!\nData: ${res['data']}'
                                        : '❌ Raw push FAILED: ${res['error'] ?? res['data']}';
                                  });
                                },
                          icon: const Icon(Icons.bolt_rounded, size: 16),
                          label: Text(
                            'Phase 14: Send Raw Token Push ⚡',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Phase 5: Standard User Push Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: isTesting
                              ? null
                              : () async {
                                  setDialogState(() {
                                    isTesting = true;
                                    testStatus = 'Dispatching test notification via user ID pipeline...';
                                  });
                                  final pushService = ref.read(pushNotificationServiceProvider);
                                  final result = await pushService.sendTestPushNotification();
                                  setDialogState(() {
                                    isTesting = false;
                                    if (result['success'] == true) {
                                      testStatus = '✅ Success! Push dispatched: ${result['data']}';
                                    } else {
                                      testStatus = '⚠️ Error: ${result['error'] ?? result['data']}';
                                    }
                                  });
                                },
                          icon: isTesting
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, size: 16),
                          label: Text(
                            isTesting ? 'Dispatching...' : 'Send Test Notification (User ID) 🔔',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Close', style: TextStyle(color: Colors.white54))),
              ],
            );
          },
        );
      },
    );
  }

  void _showMaintenanceConfirm(BuildContext context, Color accent, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Enable Maintenance Mode?', style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
        content: const Text('This will lock out all students and faculty immediately. Only admins can access the system. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

