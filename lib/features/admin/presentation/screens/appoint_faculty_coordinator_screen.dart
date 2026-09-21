import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/admin_provider.dart';
import '../providers/departments_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/theme_extensions.dart';

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
  String? _selectedDepartment;
  bool _isLoading = false;

  Map<String, dynamic>? _selectedFaculty;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onFacultySelected(Map<String, dynamic>? faculty) {
    setState(() {
      _selectedFaculty = faculty;
      _emailController.text = faculty?['email'] ?? '';
      if (faculty?['department'] != null &&
          faculty!['department'].toString().isNotEmpty) {
        _selectedDepartment = faculty['department'];
      }
    });
  }

  Future<void> _appointFc() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final adminProfile = ref.read(authNotifierProvider).value;
      final appointedBy = adminProfile?.id ?? '';
      if (appointedBy.isEmpty) throw Exception('Admin profile not found.');

      final repo = ref.read(userManagementRepositoryProvider);
      await repo.appointFacultyCoordinator(
        email: _emailController.text.trim(),
        department: _selectedDepartment!,
        appointedBy: appointedBy,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${_selectedFaculty?['name'] ?? _emailController.text} appointed as Faculty Coordinator for $_selectedDepartment!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _selectedFaculty = null;
          _selectedDepartment = null;
          _emailController.clear();
        });
        ref.invalidate(facultyListProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final facultyAsync = ref.watch(facultyListProvider);
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
        backgroundColor: theme.scaffoldBackgroundColor,
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
          title: Text('Appoint Faculty Coordinator',
              style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign Faculty Coordinator',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Faculty Coordinators verify student registrations and manage department-specific placement approvals.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: brandTheme?.textMuted),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Faculty Dropdown ──
                    Text('Select Registered Faculty',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),

                    facultyAsync.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, _) => Text(
                        'Could not load faculty list',
                        style: TextStyle(
                            color: theme.colorScheme.error, fontSize: 12),
                      ),
                      data: (facultyList) {
                        if (facultyList.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 18, color: brandTheme?.textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No faculty registered yet. They must sign up first with a @mcehassan.ac.in email.',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: brandTheme?.textMuted),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return DropdownButtonFormField<Map<String, dynamic>>(
                          initialValue: _selectedFaculty,
                          isExpanded: true,
                          hint: Text('Choose a faculty member…',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: brandTheme?.textMuted)),
                          decoration: InputDecoration(
                            prefixIcon:
                                const Icon(Icons.person_search_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                          ),
                          items: facultyList.map((faculty) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: faculty,
                              child: Text(
                                '${faculty['name']} (${faculty['email']})',
                                style: GoogleFonts.inter(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (faculty) => _onFacultySelected(faculty),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Email field ──
                    Text('Or Enter Email Manually',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) {
                        if (_selectedFaculty != null &&
                            _emailController.text !=
                                _selectedFaculty!['email']) {
                          setState(() => _selectedFaculty = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'faculty@mcehassan.ac.in',
                        prefixIcon: const Icon(Icons.email_outlined),
                        suffixIcon: _emailController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() {
                                  _emailController.clear();
                                  _selectedFaculty = null;
                                }),
                              )
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please enter or select an email address';
                        }
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Department Dropdown ──
                    Text('Assign Department',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),

                    deptsAsync.when(
                      loading: () => const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Error loading departments: $e',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                      data: (departments) {
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedDepartment,
                          isExpanded: true,
                          hint: Text('Select Department…',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: brandTheme?.textMuted)),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.apartment_rounded),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                          ),
                          items: departments.map((d) {
                            return DropdownMenuItem<String>(
                              value: d.name,
                              child: Text(
                                '${d.branchCode} · ${d.name}',
                                style: GoogleFonts.inter(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedDepartment = val),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Please select a department'
                              : null,
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // ── Appoint button ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _appointFc,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.verified_user_outlined),
                        label: Text(
                          _isLoading
                              ? 'Appointing...'
                              : 'Appoint Faculty Coordinator',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
