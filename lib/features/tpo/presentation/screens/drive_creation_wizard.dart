import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/presentation/widgets/status_thread_widget.dart';
import '../../../../shared/presentation/widgets/subtle_divider.dart';
import '../../../admin/presentation/providers/departments_provider.dart';
import '../../../admin/domain/entities/department.dart';
import '../providers/tpo_provider.dart';

import '../../../student/domain/entities/drive.dart';
import '../../../../core/services/email_notification_service.dart';

class DriveCreationWizard extends ConsumerStatefulWidget {
  final Drive? driveToEdit;

  const DriveCreationWizard({this.driveToEdit, super.key});

  @override
  ConsumerState<DriveCreationWizard> createState() => _DriveCreationWizardState();
}

class _DriveCreationWizardState extends ConsumerState<DriveCreationWizard> {
  int _currentStep = 0;
  final _basicDetailsFormKey = GlobalKey<FormState>();
  final _eligibilityFormKey = GlobalKey<FormState>();
  final _roundsFormKey = GlobalKey<FormState>();

  // Basic Details
  late final TextEditingController _companyController;
  late final TextEditingController _roleController;
  late final TextEditingController _ctcController;
  late final TextEditingController _descriptionController;

  // Eligibility & Schedule
  late final TextEditingController _cgpaCutoffController;
  late final TextEditingController _backlogsLimitController;
  late final List<String> _branches;
  late DateTime _selectedDeadline;

  // Rounds
  final List<String> _rounds = ['Aptitude Test', 'Technical Interview', 'HR Interview'];
  final _roundController = TextEditingController();

  bool get _isEditMode => widget.driveToEdit != null;

  @override
  void initState() {
    super.initState();
    final d = widget.driveToEdit;
    _companyController = TextEditingController(text: d?.companyName ?? '');
    _roleController = TextEditingController(text: d?.roleTitle ?? '');
    _ctcController = TextEditingController(text: d?.ctcOrStipend ?? '');
    _descriptionController = TextEditingController(text: d?.jobDescription ?? '');
    _cgpaCutoffController = TextEditingController(text: d != null ? '${d.cgpaCutoff}' : '7.0');
    _backlogsLimitController = TextEditingController(text: d != null ? '${d.backlogLimit}' : '0');
    _branches = d != null && d.eligibilityBranches.isNotEmpty
        ? List<String>.from(d.eligibilityBranches)
        : [];
    _selectedDeadline = d?.applicationDeadline ?? DateTime.now().add(const Duration(days: 14));
  }

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    _ctcController.dispose();
    _descriptionController.dispose();
    _cgpaCutoffController.dispose();
    _backlogsLimitController.dispose();
    _roundController.dispose();
    super.dispose();
  }

  void _onStepContinue() {
    if (_currentStep == 0 && !_basicDetailsFormKey.currentState!.validate()) return;
    if (_currentStep == 1 && !_eligibilityFormKey.currentState!.validate()) return;

    if (_currentStep < 2) {
      setState(() => _currentStep += 1);
    } else {
      _submitDrive();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  bool _isSubmitting = false;

  Future<void> _submitDrive() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(tpoRepositoryProvider);
      final user = Supabase.instance.client.auth.currentUser;
      final createdBy = user?.id ?? '';

      // Company handling
      final companyName = _companyController.text.trim();
      String companyId = '';

      if (_isEditMode) {
        companyId = widget.driveToEdit!.companyId;
        if (companyId.isNotEmpty && companyName.isNotEmpty) {
          // UPDATE existing company row in-place directly in companies table
          await repo.updateCompany(companyId: companyId, name: companyName);
        }
      } else {
        final companies = await repo.getCompanies();

        // Check if company already exists (case-insensitive)
        final existingCompany = companies
            .where((c) => c.name.trim().toLowerCase() == companyName.toLowerCase())
            .firstOrNull;

        if (existingCompany != null) {
          companyId = existingCompany.id;
        } else if (companyName.isNotEmpty) {
          await repo.createCompany(
            name: companyName,
            createdBy: createdBy,
          );
          final updatedCompanies = await repo.getCompanies();
          final newlyCreated = updatedCompanies
              .where((c) => c.name.trim().toLowerCase() == companyName.toLowerCase())
              .firstOrNull;
          companyId = newlyCreated?.id ?? (updatedCompanies.isNotEmpty ? updatedCompanies.first.id : '');
        }
      }

      final cgpa = double.tryParse(_cgpaCutoffController.text.trim()) ?? 0.0;
      final backlogs = int.tryParse(_backlogsLimitController.text.trim()) ?? 0;

      String targetDriveId = _isEditMode ? widget.driveToEdit!.id : '';
      if (_isEditMode) {
        await repo.updateDrive(
          driveId: targetDriveId,
          companyId: companyId,
          roleTitle: _roleController.text.trim(),
          ctcOrStipend: _ctcController.text.trim(),
          jobDescription: _descriptionController.text.trim(),
          eligibilityBranches: _branches,
          cgpaCutoff: cgpa,
          backlogLimit: backlogs,
          applicationDeadline: _selectedDeadline,
        );
      } else {
        targetDriveId = await repo.createDrive(
          companyId: companyId,
          roleTitle: _roleController.text.trim(),
          ctcOrStipend: _ctcController.text.trim(),
          jobDescription: _descriptionController.text.trim(),
          eligibilityBranches: _branches,
          cgpaCutoff: cgpa,
          backlogLimit: backlogs,
          applicationDeadline: _selectedDeadline,
          status: 'active',
          createdBy: createdBy,
        );
      }

      // Save rounds to drive_rounds table
      if (targetDriveId.isNotEmpty && _rounds.isNotEmpty) {
        await repo.saveDriveRounds(
          driveId: targetDriveId,
          roundNames: _rounds,
          createdBy: createdBy,
        );
      }

      // Refresh drives list globally across the app
      ref.invalidate(tpoDrivesProvider);
      // Invalidate rounds provider so round management screen refreshes
      if (targetDriveId.isNotEmpty) {
        ref.invalidate(driveRoundsProvider(targetDriveId));
      }

      // ── Dispatch Drive Published Email to Eligible Students ─────────
      if (!_isEditMode && targetDriveId.isNotEmpty) {
        try {
          final companyRes = await Supabase.instance.client
              .from('companies')
              .select('name')
              .eq('id', companyId)
              .maybeSingle();
          final companyName = (companyRes?['name'] as String?) ?? 'Company';
          final roleTitle = _roleController.text.trim();
          final package = _ctcController.text.trim();
          final deadlineStr = '${_selectedDeadline.day}/${_selectedDeadline.month}/${_selectedDeadline.year}';

          // Query eligible approved students
          final studentProfiles = await Supabase.instance.client
              .from('profiles')
              .select('id, email, name, cgpa, active_backlogs, department')
              .eq('role', 'student')
              .eq('approval_status', 'approved');

          final emailService = ref.read(emailNotificationServiceProvider);

          for (final student in (studentProfiles as List)) {
            final email = student['email'] as String?;
            final studentCgpa = (student['cgpa'] as num?)?.toDouble() ?? 0.0;
            final studentBacklogs = (student['active_backlogs'] as num?)?.toInt() ?? 0;
            final studentDept = student['department'] as String?;

            // Filter CGPA Cutoff
            if (cgpa > 0 && studentCgpa < cgpa) continue;

            // Filter Backlogs Limit
            if (backlogs >= 0 && studentBacklogs > backlogs) continue;

            // Filter Branch / Department
            if (_branches.isNotEmpty && studentDept != null) {
              final isDeptEligible = _branches.any((b) =>
                  b.toLowerCase() == studentDept.toLowerCase() ||
                  studentDept.toLowerCase().contains(b.toLowerCase()));
              if (!isDeptEligible) continue;
            }

            final studentName = (student['name'] as String?) ?? 'Student';
            if (email != null && email.contains('@')) {
              emailService.sendDrivePublishedEmail(
                recipientEmail: email,
                studentName: studentName,
                companyName: companyName,
                roleTitle: roleTitle,
                package: package,
                registrationDeadline: deadlineStr,
              );
            }

            // Save in-app notification to Supabase notifications table
            final studentId = student['id'] as String?;
            if (studentId != null) {
              await Supabase.instance.client.from('notifications').insert({
                'user_id': studentId,
                'title': 'New Drive Announced: $companyName',
                'body': 'Role: $roleTitle | Package: $package | Deadline: $deadlineStr',
                'type': 'info',
                'drive_id': targetDriveId,
              });
            }
          }

          // Directly trigger FCM Push Edge Function (no webhooks needed!)
          try {
            await Supabase.instance.client.functions.invoke('send-fcm-push', body: {
              'id': targetDriveId,
              'company_id': companyId,
              'role_title': roleTitle,
              'package_lpa': package,
              'skip_in_app': true,
            });
          } catch (fcmErr) {
            debugPrint('[DriveCreation] FCM push invoke warning: $fcmErr');
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? '✅ Drive updated successfully!' : '✅ New placement drive created & published!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Failed to save drive: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
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

    final stepsData = [
      const StatusNodeData(label: 'Basic Info', isDone: true),
      StatusNodeData(label: 'Eligibility', isDone: _currentStep > 0, isCurrent: _currentStep == 1),
      StatusNodeData(label: 'Rounds', isDone: _currentStep > 1, isCurrent: _currentStep == 2),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Placement Drive' : 'Create Placement Drive', style: GoogleFonts.fraunces(fontWeight: FontWeight.w600)),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Step Progress Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp5, vertical: AppSpacing.sp4),
              color: theme.colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STEP ${_currentStep + 1} OF 3',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: brandTheme.brassPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sp3),
                      Expanded(
                        child: Text(
                          _currentStep == 0
                              ? 'Basic Company Info'
                              : _currentStep == 1
                                  ? 'Eligibility Criteria'
                                  : 'Recruitment Rounds',
                          textAlign: TextAlign.end,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: brandTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sp3),
                  StatusThreadWidget(nodes: stepsData),
                ],
              ),
            ),
            const SubtleDivider(height: 1, thickness: 1),

            // Step Content Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.sp5),
                child: _buildCurrentStepForm(theme, brandTheme, departmentsAsync),
              ),
            ),

            // Bottom Navigation Action Buttons
            Container(
              padding: const EdgeInsets.all(AppSpacing.sp5),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: brandTheme.cardBorder)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: GestureDetector(
                        onTap: _onStepCancel,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: brandTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                            border: Border.all(color: brandTheme.cardBorder),
                          ),
                          child: Center(
                            child: Text(
                              'Back',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: AppSpacing.sp3),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _onStepContinue,
child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp3, vertical: AppSpacing.sp3),
                        decoration: BoxDecoration(
                          gradient: brandTheme.brassGradient,
                          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                          boxShadow: [
                            BoxShadow(
                              color: brandTheme.brassSoft,
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _currentStep == 2 ? (_isEditMode ? 'Save Changes' : 'Publish Drive') : 'Continue to Next Step',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: brandTheme.onBrass,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepForm(ThemeData theme, AppBrandTheme brandTheme, AsyncValue<List<Department>> departmentsAsync) {
    switch (_currentStep) {
      case 0:
        return Form(
          key: _basicDetailsFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldHeader('COMPANY NAME', brandTheme),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(hintText: 'e.g. PhonePe, Razorpay'),
                validator: (v) => v == null || v.isEmpty ? 'Company name is required' : null,
              ),
              const SizedBox(height: AppSpacing.sp4),

              _fieldHeader('ROLE TITLE', brandTheme),
              TextFormField(
                controller: _roleController,
                decoration: const InputDecoration(hintText: 'e.g. Software Development Engineer-1'),
                validator: (v) => v == null || v.isEmpty ? 'Role title is required' : null,
              ),
              const SizedBox(height: AppSpacing.sp4),

              _fieldHeader('CTC / STIPEND', brandTheme),
              TextFormField(
                controller: _ctcController,
                decoration: const InputDecoration(hintText: 'e.g. ₹18 LPA or ₹50,000 / month'),
                validator: (v) => v == null || v.isEmpty ? 'CTC / Stipend is required' : null,
              ),
              const SizedBox(height: AppSpacing.sp4),

              _fieldHeader('JOB DESCRIPTION', brandTheme),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Enter role expectations, responsibilities, and benefits...'),
              ),
            ],
          ),
        );
      case 1:
        return Form(
          key: _eligibilityFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldHeader('MINIMUM CGPA', brandTheme),
                        TextFormField(
                          controller: _cgpaCutoffController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(hintText: '7.0'),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sp3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldHeader('MAX BACKLOGS', brandTheme),
                        TextFormField(
                          controller: _backlogsLimitController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '0'),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sp4),
              _fieldHeader('APPLICATION DEADLINE (END DATE)', brandTheme),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDeadline,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDeadline = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                    border: Border.all(color: brandTheme.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDeadline.day}/${_selectedDeadline.month}/${_selectedDeadline.year}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Icon(Icons.calendar_month_rounded, color: brandTheme.brassPrimary, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sp5),
              _fieldHeader('ELIGIBLE BRANCHES', brandTheme),
              if (departmentsAsync.hasValue)
                ActionChip(
                  label: Text('All Branches', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                  backgroundColor: brandTheme.surfaceAlt,
                  onPressed: () {
                    setState(() {
                      _branches.clear();
                      _branches.addAll(departmentsAsync.value!.map((d) => d.branchCode));
                    });
                  },
                ),
              if (departmentsAsync.hasValue) ...[
                const SizedBox(height: AppSpacing.sp4),
                ActionChip(
                  avatar: Icon(Icons.tune_rounded, size: 16, color: brandTheme.brassPrimary),
                  label: Text(
                    _branches.isEmpty
                        ? 'Choose Specific Departments'
                        : '${_branches.length} department${_branches.length == 1 ? '' : 's'} selected',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _branches.isEmpty ? brandTheme.textMuted : brandTheme.brassPrimary),
                  ),
                  backgroundColor: _branches.isEmpty ? brandTheme.surfaceAlt : brandTheme.brassSoft,
                  side: BorderSide(color: _branches.isEmpty ? brandTheme.cardBorder : brandTheme.brassPrimary.withOpacity(0.3)),
                  onPressed: () => _showDepartmentPicker(departmentsAsync.value!, brandTheme),
                ),
              ],
              if (_branches.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sp4),
                Wrap(
                  spacing: AppSpacing.sp2,
                  runSpacing: AppSpacing.sp2,
                  children: _branches.map((branch) {
                    return Chip(
                      label: Text(branch, style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w700)),
                      backgroundColor: brandTheme.brassSoft,
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      onDeleted: () => setState(() => _branches.remove(branch)),
                      side: BorderSide(color: brandTheme.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      case 2:
        return Form(
          key: _roundsFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldHeader('RECRUITMENT ROUNDS SEQUENCE', brandTheme),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _roundController,
                      decoration: const InputDecoration(hintText: 'e.g. Coding Assessment'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sp2),
                  GestureDetector(
                    onTap: () {
                      if (_roundController.text.trim().isNotEmpty) {
                        setState(() {
                          _rounds.add(_roundController.text.trim());
                          _roundController.clear();
                        });
                      }
                    },
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: brandTheme.brassGradient,
                        borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
                      ),
                      child: Icon(Icons.add_rounded, color: brandTheme.onBrass),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sp4),

              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rounds.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _rounds.removeAt(oldIndex);
                    _rounds.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, idx) {
                  final roundName = _rounds[idx];
                  return Container(
                    key: ValueKey('round_${roundName}_$idx'),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sp2),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp4, vertical: 12),
                    decoration: ShapeDecoration(
                      color: theme.colorScheme.surface,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
                        side: BorderSide(color: brandTheme.cardBorder),
                      ),
                    ),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: idx,
                          child: Icon(Icons.drag_indicator_rounded, size: 20, color: brandTheme.textMuted),
                        ),
                        const SizedBox(width: AppSpacing.sp2),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: brandTheme.brassSoft,
                          ),
                          child: Center(
                            child: Text(
                              '${idx + 1}',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: brandTheme.brassPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sp3),
                        Expanded(
                          child: Text(
                            roundName,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: brandTheme.textMuted),
                          onPressed: () => setState(() => _rounds.removeAt(idx)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      default:
        return const SizedBox();
    }
  }

  void _showDepartmentPicker(List<Department> departments, AppBrandTheme brandTheme) {
    final selected = Set<String>.from(_branches);
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = departments.where((d) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return d.branchCode.toLowerCase().contains(q) || d.name.toLowerCase().contains(q);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: brandTheme.textMuted.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.sp5, AppSpacing.sp4, AppSpacing.sp5, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select Departments', style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '${selected.length} of ${departments.length} selected',
                                style: GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _branches.clear();
                              _branches.addAll(selected);
                            });
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: brandTheme.brassGradient,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text('Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: brandTheme.onBrass)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sp3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp5),
                    child: TextField(
                      onChanged: (val) => setSheetState(() => searchQuery = val),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search departments...',
                        hintStyle: GoogleFonts.inter(color: brandTheme.textMuted),
                        prefixIcon: Icon(Icons.search_rounded, color: brandTheme.textMuted, size: 20),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: brandTheme.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: brandTheme.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: brandTheme.brassPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sp3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp5),
                    child: Wrap(
                      spacing: AppSpacing.sp2,
                      runSpacing: AppSpacing.sp2,
                      children: [
                        _pickerActionChip('Select All', Icons.check_circle_outline_rounded, brandTheme, () {
                          setSheetState(() => selected.addAll(departments.map((d) => d.branchCode)));
                        }),
                        _pickerActionChip('Clear All', Icons.remove_circle_outline_rounded, brandTheme, () {
                          setSheetState(() => selected.clear());
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sp3),
                  const SubtleDivider(),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: brandTheme.textMuted.withOpacity(0.4)),
                                const SizedBox(height: 8),
                                Text('No departments found', style: GoogleFonts.inter(color: brandTheme.textMuted, fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sp5, vertical: AppSpacing.sp3),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 2),
                            itemBuilder: (_, i) {
                              final dept = filtered[i];
                              final isSelected = selected.contains(dept.branchCode);
                              return GestureDetector(
                                onTap: () {
                                  setSheetState(() {
                                    if (isSelected) {
                                      selected.remove(dept.branchCode);
                                    } else {
                                      selected.add(dept.branchCode);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? brandTheme.brassPrimary : brandTheme.cardBorder,
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: isSelected ? brandTheme.brassPrimary : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isSelected ? brandTheme.brassPrimary : brandTheme.textMuted.withOpacity(0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: isSelected
                                            ? Icon(Icons.check_rounded, size: 14, color: brandTheme.onBrass)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        constraints: const BoxConstraints(minWidth: 28),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            dept.branchCode,
                                            maxLines: 1,
                                            style: GoogleFonts.ibmPlexMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: brandTheme.textMuted,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          dept.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: brandTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: AppSpacing.sp4),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  }

  Widget _pickerActionChip(String label, IconData icon, AppBrandTheme brandTheme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: brandTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: brandTheme.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: brandTheme.textMuted),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: brandTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _fieldHeader(String title, AppBrandTheme brandTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        title,
        style: GoogleFonts.ibmPlexMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: brandTheme.textMuted,
        ),
      ),
    );
  }
}
