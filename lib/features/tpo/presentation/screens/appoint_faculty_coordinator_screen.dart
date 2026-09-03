import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../admin/presentation/providers/departments_provider.dart';
import '../providers/tpo_provider.dart';

class AppointFacultyCoordinatorScreen extends ConsumerStatefulWidget {
  const AppointFacultyCoordinatorScreen({super.key});

  @override
  ConsumerState<AppointFacultyCoordinatorScreen> createState() =>
      _AppointFacultyCoordinatorScreenState();
}

class _AppointFacultyCoordinatorScreenState
    extends ConsumerState<AppointFacultyCoordinatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String? _selectedDept;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final email = _emailController.text.trim();

      // 1. Verify user exists in profiles table
      final userRes = await Supabase.instance.client
          .from('profiles')
          .select('id, name, role, email')
          .eq('email', email)
          .maybeSingle();

      if (userRes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Faculty account not found.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      final role = userRes['role'] as String? ?? '';
      if (role != 'faculty' && role != 'faculty_coordinator') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Account found, but role is "$role" (not Faculty).'),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      final profileId = userRes['id'] as String;
      final currentUser = Supabase.instance.client.auth.currentUser;
      final adminId = currentUser?.id ?? '';

      // 2. Perform appointment in Supabase
      final repo = ref.read(tpoRepositoryProvider);
      await repo.appointFacultyCoordinator(
        profileId: profileId,
        department: _selectedDept!,
        appointedBy: adminId,
      );

      // 3. Immediately refresh coordinator list across app
      ref.invalidate(facultyCoordinatorsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Successfully appointed ${userRes['name'] ?? email} as Coordinator for $_selectedDept!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Appointment failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final departmentsAsync = ref.watch(departmentsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/tpo');
        }
      },
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/tpo');
            }
          },
        ),
        title: Text(
          'Appoint Faculty Coordinator',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sp5),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: brandTheme.brassSoft.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: brandTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1_rounded,
                          size: 28, color: brandTheme.brassPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Appoint an existing registered faculty member as the Coordinator lead for a department.',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: theme.colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sp5),

                // Faculty Email Field
                Text(
                  'FACULTY EMAIL',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: brandTheme.brassPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'e.g. faculty@mcehassan.ac.in',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Faculty email is required';
                    }
                    if (!v.contains('@')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sp5),

                // Department Selector Field
                Text(
                  'DEPARTMENT (REQUIRED)',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: brandTheme.brassPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDept,
                  isExpanded: true,
                  hint: Text(
                    'Select Department',
                    style: GoogleFonts.inter(color: brandTheme.textMuted),
                  ),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: departmentsAsync.hasValue
                      ? departmentsAsync.value!
                          .map((d) => DropdownMenuItem<String>(
                                value: d.branchCode,
                                child: Text('${d.branchCode} — ${d.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              ))
                          .toList()
                      : [],
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select a department.';
                    }
                    return null;
                  },
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDept = val);
                  },
                ),
                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAppointment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandTheme.brassPrimary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.black),
                          )
                        : Text(
                            'Confirm Appointment',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
