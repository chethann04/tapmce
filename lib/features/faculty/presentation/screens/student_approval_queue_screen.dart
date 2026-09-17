import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/domain/entities/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/faculty_provider.dart';
import '../../../student/presentation/screens/profile_setup_screen.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../shared/presentation/widgets/app_refresh_indicator.dart';

class StudentApprovalQueueScreen extends ConsumerStatefulWidget {
  const StudentApprovalQueueScreen({super.key});

  @override
  ConsumerState<StudentApprovalQueueScreen> createState() =>
      _StudentApprovalQueueScreenState();
}

class _StudentApprovalQueueScreenState
    extends ConsumerState<StudentApprovalQueueScreen> {
  final Map<String, bool> _processingIds = {};
  final Set<String> _selectedStudentIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleStudentSelection(String id) {
    setState(() {
      if (_selectedStudentIds.contains(id)) {
        _selectedStudentIds.remove(id);
      } else {
        _selectedStudentIds.add(id);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedStudentIds.clear();
    });
  }

  void _selectAll(List<UserProfile> students) {
    setState(() {
      _selectedStudentIds.addAll(students.map((s) => s.id));
    });
  }

  Future<void> _approveStudent(UserProfile student) async {
    final currentFC = ref.read(authNotifierProvider).value;
    if (currentFC == null) return;

    setState(() => _processingIds[student.id] = true);
    try {
      final repo = ref.read(facultyRepositoryProvider);
      await repo.reviewStudentApproval(
        studentId: student.id,
        status: ApprovalStatus.approved,
        approvedBy: currentFC.id,
      );

      _selectedStudentIds.remove(student.id);
      ref.invalidate(pendingStudentsProvider);
      ref.invalidate(verifiedStudentsProvider);
      ref.invalidate(rejectedStudentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Approved ${student.name} (${student.usn ?? ''})'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error approving student: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(student.id));
    }
  }

  Future<void> _batchApprove(List<UserProfile> allStudents) async {
    final selectedStudents = allStudents.where((s) => _selectedStudentIds.contains(s.id)).toList();
    if (selectedStudents.isEmpty) return;

    final currentFC = ref.read(authNotifierProvider).value;
    if (currentFC == null) return;

    final count = selectedStudents.length;
    setState(() {
      for (final s in selectedStudents) {
        _processingIds[s.id] = true;
      }
    });

    try {
      final repo = ref.read(facultyRepositoryProvider);
      for (final student in selectedStudents) {
        await repo.reviewStudentApproval(
          studentId: student.id,
          status: ApprovalStatus.approved,
          approvedBy: currentFC.id,
        );
      }

      _clearSelection();
      ref.invalidate(pendingStudentsProvider);
      ref.invalidate(verifiedStudentsProvider);
      ref.invalidate(rejectedStudentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully approved $count students!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error approving batch: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.clear());
    }
  }

  void _batchReject(List<UserProfile> allStudents) {
    final selectedStudents = allStudents.where((s) => _selectedStudentIds.contains(s.id)).toList();
    if (selectedStudents.isEmpty) return;

    final reasonCtrl = TextEditingController();
    final currentFC = ref.read(authNotifierProvider).value;
    if (currentFC == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Batch Reject (${selectedStudents.length} Students)',
            style: GoogleFonts.fraunces(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Provide a reason for rejecting the selected ${selectedStudents.length} registrations:',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Enter rejection reason (Required)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) return;

                final messenger = ScaffoldMessenger.of(context);
                final theme = Theme.of(context);
                Navigator.pop(context);
                setState(() {
                  for (final s in selectedStudents) {
                    _processingIds[s.id] = true;
                  }
                });

                try {
                  final repo = ref.read(facultyRepositoryProvider);
                  for (final student in selectedStudents) {
                    await repo.reviewStudentApproval(
                      studentId: student.id,
                      status: ApprovalStatus.rejected,
                      approvedBy: currentFC.id,
                      rejectionReason: reason,
                    );
                  }

                  _clearSelection();
                  ref.invalidate(pendingStudentsProvider);
                  ref.invalidate(verifiedStudentsProvider);
                  ref.invalidate(rejectedStudentsProvider);

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Rejected ${selectedStudents.length} students.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: theme.colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _processingIds.clear());
                }
              },
              child: const Text('Reject All Selected'),
            ),
          ],
        );
      },
    );
  }

  void _rejectStudent(UserProfile student) {
    final reasonCtrl = TextEditingController();
    final currentFC = ref.read(authNotifierProvider).value;
    if (currentFC == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Reject Registration',
            style: GoogleFonts.fraunces(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Provide a reason for rejecting ${student.name}\'s registration:',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Enter reason (Required)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) return;

                final messenger = ScaffoldMessenger.of(context);
                final theme = Theme.of(context);
                Navigator.pop(context);
                setState(() => _processingIds[student.id] = true);
                try {
                  final repo = ref.read(facultyRepositoryProvider);
                  await repo.reviewStudentApproval(
                    studentId: student.id,
                    status: ApprovalStatus.rejected,
                    approvedBy: currentFC.id,
                    rejectionReason: reason,
                  );

                  _selectedStudentIds.remove(student.id);
                  ref.invalidate(pendingStudentsProvider);
                  ref.invalidate(verifiedStudentsProvider);
                  ref.invalidate(rejectedStudentsProvider);

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Student ${student.name} rejected.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: theme.colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _processingIds.remove(student.id));
                }
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }



  void _openFullStudentEditWizard(UserProfile student) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(
          isEditMode: true,
          targetStudent: student,
        ),
      ),
    ).then((_) {
      ref.invalidate(pendingStudentsProvider);
      ref.invalidate(verifiedStudentsProvider);
      ref.invalidate(rejectedStudentsProvider);
    });
  }

  void _showStudentDetailsModal(UserProfile student, AppBrandTheme? brandTheme, ThemeData theme, bool isPending) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (brandTheme?.textMuted ?? Colors.grey).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: (brandTheme?.brassPrimary ?? Colors.amber).withValues(alpha: 0.15),
                    backgroundImage: (student.photoUrl != null && student.photoUrl!.isNotEmpty)
                        ? NetworkImage(student.photoUrl!)
                        : null,
                    child: (student.photoUrl == null || student.photoUrl!.isEmpty)
                        ? Text(
                            student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                            style: GoogleFonts.ibmPlexMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: brandTheme?.brassPrimary ?? theme.colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${student.usn ?? 'N/A'} · ${student.department ?? 'N/A'}',
                          style: GoogleFonts.inter(fontSize: 12, color: brandTheme?.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (brandTheme?.brassPrimary ?? Colors.amber).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      student.approvalStatus.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: brandTheme?.brassPrimary ?? Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                isScrollable: true,
                indicatorColor: brandTheme?.brassPrimary ?? Colors.amber,
                labelColor: brandTheme?.brassPrimary ?? Colors.amber,
                unselectedLabelColor: brandTheme?.textMuted,
                tabs: const [
                  Tab(text: 'Personal Info'),
                  Tab(text: 'Academic Info'),
                  Tab(text: 'Account Info'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    // Personal Info Tab
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _detailItem(Icons.person_outlined, 'Full Name', student.name, brandTheme),
                          _detailItem(Icons.badge_outlined, 'USN', student.usn ?? 'N/A', brandTheme),
                          _detailItem(
                            Icons.school_outlined,
                            'USN Detected Branch',
                            '${student.detectedCourseName ?? student.department ?? 'N/A'} (${student.detectedCourseCode ?? '—'})',
                            brandTheme,
                          ),
                          if (student.branchVerified)
                            _detailItem(
                              Icons.verified_outlined,
                              'Verified Branch',
                              '${student.verifiedCourseName ?? student.department ?? 'N/A'} (${student.verifiedCourseCode ?? '—'})',
                              brandTheme,
                            ),
                          _detailItem(Icons.email_outlined, 'Email', student.email, brandTheme),
                          _detailItem(Icons.phone_outlined, 'Phone', student.phone ?? 'N/A', brandTheme),
                        ],
                      ),
                    ),

                    // Academic Info Tab (Integrated Resume)
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailItem(Icons.grade_outlined, '10th Percentage', student.tenthPercent != null ? '${student.tenthPercent}%' : 'N/A', brandTheme),
                          _detailItem(Icons.school_outlined, '12th / Diploma %', student.twelfthOrDiplomaPercent != null ? '${student.twelfthOrDiplomaPercent}%' : 'N/A', brandTheme),
                          _detailItem(Icons.star_outline_rounded, 'CGPA', student.cgpa != null ? '${student.cgpa}' : 'N/A', brandTheme),
                          _detailItem(Icons.history_edu_outlined, 'Active Backlogs', '${student.activeBacklogs}', brandTheme),
                          if (student.rejectionReason != null && student.rejectionReason!.isNotEmpty)
                            _detailItem(Icons.error_outline_rounded, 'Rejection Reason', student.rejectionReason!, brandTheme, isError: true),
                          const SizedBox(height: 10),
                          Divider(color: (brandTheme?.cardBorder ?? Colors.grey).withValues(alpha: 0.3)),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(Icons.description_outlined, size: 18, color: brandTheme?.textMuted ?? Colors.grey),
                                const SizedBox(width: 10),
                                Text('Resume: ', style: GoogleFonts.inter(fontSize: 13, color: brandTheme?.textMuted)),
                                const SizedBox(width: 4),
                                if (student.resumeUrl != null && student.resumeUrl!.isNotEmpty)
                                  InkWell(
                                    onTap: () async {
                                      final urlStr = student.resumeUrl!;
                                      final uri = Uri.parse(urlStr);
                                      try {
                                        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        if (!ok) {
                                          await launchUrl(uri, mode: LaunchMode.platformDefault);
                                        }
                                      } catch (_) {
                                        try {
                                          final gdocUri = Uri.parse('https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(urlStr)}');
                                          await launchUrl(gdocUri, mode: LaunchMode.externalApplication);
                                        } catch (e) {
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                              const SnackBar(
                                                content: Text('Could not open resume. Please check internet connection or PDF viewer.'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: (brandTheme?.brassPrimary ?? Colors.amber).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: (brandTheme?.brassPrimary ?? Colors.amber).withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.picture_as_pdf_rounded, size: 15, color: brandTheme?.brassPrimary ?? Colors.amber),
                                          const SizedBox(width: 6),
                                          Text(
                                            'View Resume 📄',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: brandTheme?.brassPrimary ?? Colors.amber,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.open_in_new_rounded, size: 13, color: brandTheme?.brassPrimary ?? Colors.amber),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    'Resume not uploaded.',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade500,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Account Info Tab
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _detailItem(Icons.calendar_today_outlined, 'Registered Date', '${student.createdAt.day}/${student.createdAt.month}/${student.createdAt.year}', brandTheme),
                          _detailItem(Icons.verified_user_outlined, 'Approval Status', student.approvalStatus.name.toUpperCase(), brandTheme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Show Edit Details button for Rejected or Pending students
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openFullStudentEditWizard(student);
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 18, color: Colors.amber),
                      label: const Text(
                        'Edit Details',
                        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.amber, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Show Reject button for Pending or Approved students
                  if (student.approvalStatus == ApprovalStatus.pending || student.approvalStatus == ApprovalStatus.approved) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _rejectStudent(student);
                        },
                        icon: const Icon(Icons.close_rounded, color: Colors.red, size: 16),
                        label: Text(
                          student.approvalStatus == ApprovalStatus.approved ? 'Reject' : 'Reject',
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade300, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Show Approve button for Pending or Rejected students
                  if (student.approvalStatus == ApprovalStatus.pending || student.approvalStatus == ApprovalStatus.rejected) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _approveStudent(student);
                        },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(
                          student.approvalStatus == ApprovalStatus.rejected
                              ? 'Re-Approve'
                              : 'Approve',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value, AppBrandTheme? brandTheme, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isError ? Colors.red : (brandTheme?.textMuted ?? Colors.grey)),
          const SizedBox(width: 10),
          Text('$label: ', style: GoogleFonts.inter(fontSize: 13, color: brandTheme?.textMuted)),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isError ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>();
    final accent = brandTheme?.brassPrimary ?? theme.colorScheme.primary;

    final pendingAsync = ref.watch(pendingStudentsProvider);
    final verifiedAsync = ref.watch(verifiedStudentsProvider);
    final rejectedAsync = ref.watch(rejectedStudentsProvider);

    final pendingList = pendingAsync.value ?? [];
    final verifiedList = verifiedAsync.value ?? [];
    final rejectedList = rejectedAsync.value ?? [];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/faculty');
        }
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/faculty');
                }
              },
            ),
            title: Text(
              'Student Verification',
              style: GoogleFonts.fraunces(fontWeight: FontWeight.w600),
            ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ref.invalidate(pendingStudentsProvider);
                ref.invalidate(verifiedStudentsProvider);
                ref.invalidate(rejectedStudentsProvider);
              },
              tooltip: 'Refresh Queue',
            ),
          ],
          bottom: TabBar(
            indicatorColor: accent,
            labelColor: accent,
            unselectedLabelColor: brandTheme?.textMuted,
            tabs: [
              Tab(text: 'Pending (${pendingList.length})'),
              Tab(text: 'Approved (${verifiedList.length})'),
              Tab(text: 'Rejected (${rejectedList.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Embedded Search Bar & Filter Button
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141519),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                              cursorColor: brandTheme?.brassPrimary ?? Colors.amber,
                              decoration: InputDecoration(
                                hintText: 'Search by name, USN or email',
                                hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.35)),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                filled: false,
                                fillColor: Colors.transparent,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                setState(() => _searchQuery = val.trim().toLowerCase());
                              },
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white54),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141519),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.filter_list_rounded, size: 18, color: Colors.white.withValues(alpha: 0.7)),
                      onPressed: () {},
                      tooltip: 'Filter',
                    ),
                  ),
                ],
              ),
            ),

            // Select All / Selection Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Builder(
                builder: (context) {
                  final activeTab = DefaultTabController.of(context).index;
                  final currentTabList = activeTab == 0
                      ? pendingList
                      : activeTab == 1
                          ? verifiedList
                          : rejectedList;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _selectedStudentIds.isNotEmpty && _selectedStudentIds.length == currentTabList.length && currentTabList.isNotEmpty,
                              activeColor: accent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                if (val == true) {
                                  _selectAll(currentTabList);
                                } else {
                                  _clearSelection();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedStudentIds.isEmpty ? 'Select Students' : '${_selectedStudentIds.length} selected',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (_selectedStudentIds.isNotEmpty)
                        TextButton(
                          onPressed: _clearSelection,
                          child: Text(
                            'Deselect All',
                            style: GoogleFonts.inter(fontSize: 12, color: accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // Tab View with Student Cards
            Expanded(
              child: TabBarView(
                children: [
                  _buildStudentList(pendingAsync, theme, brandTheme, accent, isPending: true),
                  _buildStudentList(verifiedAsync, theme, brandTheme, accent, isPending: false),
                  _buildStudentList(rejectedAsync, theme, brandTheme, accent, isPending: false),
                ],
              ),
            ),

            // Sleek Floating Action Bar when items selected
            if (_selectedStudentIds.isNotEmpty)
              Builder(
                builder: (context) {
                  final activeTab = DefaultTabController.of(context).index;
                  final combinedList = [...pendingList, ...verifiedList, ...rejectedList];

                  return Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 95),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: (brandTheme?.brassPrimary ?? accent).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '${_selectedStudentIds.length} Selected',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (activeTab == 0 || activeTab == 2) ...[
                            InkWell(
                              onTap: () => _batchApprove(combinedList),
                              borderRadius: BorderRadius.circular(100),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      activeTab == 2 ? 'Re-Approve' : 'Approve',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          if (activeTab == 0 || activeTab == 1) ...[
                            if (activeTab == 0) const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _batchReject(combinedList),
                              borderRadius: BorderRadius.circular(100),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Reject',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildStudentList(AsyncValue<List<UserProfile>> asyncValue, ThemeData theme, AppBrandTheme? brandTheme, Color accent, {required bool isPending}) {
    return asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(err.toString(), style: GoogleFonts.inter(color: Colors.red)),
        ),
      ),
      data: (students) {
        final filteredStudents = _searchQuery.isEmpty
            ? students
            : students.where((s) {
                final nameMatch = s.name.toLowerCase().contains(_searchQuery);
                final usnMatch = s.usn != null && s.usn!.toLowerCase().contains(_searchQuery);
                final emailMatch = s.email.toLowerCase().contains(_searchQuery);
                final deptMatch = s.department != null && s.department!.toLowerCase().contains(_searchQuery);
                return nameMatch || usnMatch || emailMatch || deptMatch;
              }).toList();

        if (filteredStudents.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.folder_off_outlined, size: 48, color: brandTheme?.textMuted),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isNotEmpty ? 'No Matching Students' : 'No Students Found',
                  style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'No results for "$_searchQuery"',
                    style: GoogleFonts.inter(fontSize: 13, color: brandTheme?.textMuted),
                  ),
                ],
              ],
            ),
          );
        }
        return AppRefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(pendingStudentsProvider.future),
              ref.refresh(verifiedStudentsProvider.future),
              ref.refresh(rejectedStudentsProvider.future),
            ]);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 20),
            itemCount: filteredStudents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final student = filteredStudents[index];
              final isSelected = _selectedStudentIds.contains(student.id);

              return InkWell(
                onTap: () => _showStudentDetailsModal(student, brandTheme, theme, isPending),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? accent.withValues(alpha: 0.08) : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? accent
                          : (brandTheme?.cardBorder ?? theme.colorScheme.outline),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isSelected,
                          activeColor: accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (_) => _toggleStudentSelection(student.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: accent.withValues(alpha: 0.15),
                        child: Text(
                          student.name.isNotEmpty ? student.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase() : 'S',
                          style: GoogleFonts.ibmPlexMono(fontWeight: FontWeight.bold, color: accent, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${student.usn ?? 'N/A'}  •  ${student.department ?? 'N/A'}',
                              style: GoogleFonts.inter(fontSize: 11, color: brandTheme?.textMuted),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: student.approvalStatus == ApprovalStatus.approved
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : student.approvalStatus == ApprovalStatus.rejected
                                        ? Colors.red.withValues(alpha: 0.15)
                                        : accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                student.approvalStatus.displayName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: student.approvalStatus == ApprovalStatus.approved
                                      ? Colors.green
                                      : student.approvalStatus == ApprovalStatus.rejected
                                          ? Colors.red
                                          : accent,
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
            },
          ),
        );
      },
    );
  }
}

