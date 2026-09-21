import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/course.dart';
import '../../data/datasources/course_datasource.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_spacing.dart';

class CourseManagementScreen extends ConsumerStatefulWidget {
  const CourseManagementScreen({super.key});

  @override
  ConsumerState<CourseManagementScreen> createState() =>
      _CourseManagementScreenState();
}

class _CourseManagementScreenState
    extends ConsumerState<CourseManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;

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
          title: Text(
            'UG Programs & Course Master',
            style: GoogleFonts.fraunces(fontWeight: FontWeight.w600),
          ),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
        ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brandTheme.brassPrimary,
        foregroundColor: theme.brightness == Brightness.dark ? const Color(0xFF0A0A0B) : Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Program', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        onPressed: () => _showAddEditCourseModal(context, null, brandTheme, theme),
      ),
      body: coursesAsync.when(
        data: (courses) {
          final categories = <String>[
            'All',
            ...courses.map((c) => c.category).toSet(),
          ];

          final filtered = courses.where((c) {
            final matchesQuery = c.courseName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.courseCode.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesCat = _selectedCategory == 'All' || c.category == _selectedCategory;
            return matchesQuery && matchesCat;
          }).toList();

          return Column(
            children: [
              // Search & Filter header
              Container(
                padding: const EdgeInsets.all(AppSpacing.sp4),
                color: theme.colorScheme.surface,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search by program name or code (e.g. CS, IS, ME)...',
                        prefixIcon: Icon(Icons.search_rounded, color: brandTheme.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sp3),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                              selectedColor: brandTheme.brassSoft,
                              checkmarkColor: brandTheme.brassPrimary,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Courses list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No courses found.',
                          style: GoogleFonts.inter(color: brandTheme.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppSpacing.sp4),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final course = filtered[index];
                          return _buildCourseCard(course, brandTheme, theme);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading courses: $e')),
      ),
    ),
  );
  }

  Widget _buildCourseCard(Course course, AppBrandTheme brandTheme, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sp3),
      padding: const EdgeInsets.all(AppSpacing.sp4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
        border: Border.all(
          color: course.isActive ? brandTheme.cardBorder : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: brandTheme.brassSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              course.courseCode,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: brandTheme.brassPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseName,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  course.category,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: brandTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: course.isActive,
            activeThumbColor: brandTheme.brassPrimary,
            onChanged: (val) async {
              await ref.read(courseDatasourceProvider).toggleCourseStatus(course.id, val);
              ref.invalidate(coursesProvider);
              ref.invalidate(activeCoursesProvider);
            },
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 18, color: brandTheme.textMuted),
            onPressed: () => _showAddEditCourseModal(context, course, brandTheme, theme),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEditCourseModal(
    BuildContext context,
    Course? course,
    AppBrandTheme brandTheme,
    ThemeData theme,
  ) async {
    final nameCtrl = TextEditingController(text: course?.courseName ?? '');
    final codeCtrl = TextEditingController(text: course?.courseCode ?? '');
    final categoryCtrl = TextEditingController(text: course?.category ?? 'Computer Science / Computing');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.sp5,
          right: AppSpacing.sp5,
          top: AppSpacing.sp5,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.sp5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course == null ? 'Add New Program' : 'Edit Program',
              style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sp4),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Program / Branch Name',
                hintText: 'e.g. Computer Science & Engineering',
              ),
            ),
            const SizedBox(height: AppSpacing.sp3),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Course Code (2–3 Letters)',
                hintText: 'e.g. CS, IS, EC, ME',
              ),
            ),
            const SizedBox(height: AppSpacing.sp3),
            TextField(
              controller: categoryCtrl,
              decoration: const InputDecoration(
                labelText: 'Discipline / Category',
                hintText: 'e.g. Computer Science / Computing',
              ),
            ),
            const SizedBox(height: AppSpacing.sp5),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim().toUpperCase();
                final cat = categoryCtrl.text.trim();
                if (name.isEmpty || code.isEmpty) return;

                final ds = ref.read(courseDatasourceProvider);
                if (course == null) {
                  await ds.addCourse(courseName: name, courseCode: code, category: cat);
                } else {
                  await ds.updateCourse(
                    id: course.id,
                    courseName: name,
                    courseCode: code,
                    category: cat,
                    isActive: course.isActive,
                  );
                }
                ref.invalidate(coursesProvider);
                ref.invalidate(activeCoursesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandTheme.brassPrimary,
                foregroundColor: theme.brightness == Brightness.dark ? const Color(0xFF0A0A0B) : Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                course == null ? 'Add Program' : 'Save Changes',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

