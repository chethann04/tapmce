import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/theme_extensions.dart';

/// Export format options.
enum ExportFormat { csv, pdf }

/// Export type options.
enum ExportType { departmentWise, combined, both }

/// Professional export dialog for attendance records.
///
/// Shows department filter, format selector, and export type.
/// Generates CSV/PDF files with proper filtering.
void showAttendanceExportDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> records,
  required String companyName,
  required String roleTitle,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AttendanceExportDialog(
      records: records,
      companyName: companyName,
      roleTitle: roleTitle,
    ),
  );
}

class _AttendanceExportDialog extends StatefulWidget {
  final List<Map<String, dynamic>> records;
  final String companyName;
  final String roleTitle;

  const _AttendanceExportDialog({
    required this.records,
    required this.companyName,
    required this.roleTitle,
  });

  @override
  State<_AttendanceExportDialog> createState() => _AttendanceExportDialogState();
}

class _AttendanceExportDialogState extends State<_AttendanceExportDialog> {
  // ── State ──────────────────────────────────────────────────────────
  Set<String> _selectedDepartments = {};
  ExportFormat _format = ExportFormat.csv;
  ExportType _exportType = ExportType.combined;
  bool _isExporting = false;
  List<String> _availableDepartments = [];

  @override
  void initState() {
    super.initState();
    _extractDepartments();
  }

  void _extractDepartments() {
    final depts = <String>{};
    for (final rec in widget.records) {
      final profile = rec['profile'] as Map<String, dynamic>? ?? {};
      final dept = profile['department'] as String?;
      if (dept != null && dept.isNotEmpty) depts.add(dept);
    }
    _availableDepartments = depts.toList()..sort();
    // Default: all selected
    _selectedDepartments = Set.from(_availableDepartments);
  }

  // ── Helpers ────────────────────────────────────────────────────────
  String _getToday() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  List<Map<String, dynamic>> _filterRecords(List<Map<String, dynamic>> source) {
    if (_selectedDepartments.length == _availableDepartments.length) {
      return source;
    }
    return source.where((rec) {
      final profile = rec['profile'] as Map<String, dynamic>? ?? {};
      final dept = profile['department'] as String? ?? '';
      return _selectedDepartments.contains(dept);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupByDept(
      List<Map<String, dynamic>> records) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final rec in records) {
      final profile = rec['profile'] as Map<String, dynamic>? ?? {};
      final dept = profile['department'] as String? ?? 'Unknown';
      map.putIfAbsent(dept, () => []).add(rec);
    }
    return map;
  }

  String _deptFileName(String dept) {
    final clean = dept.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return '${clean}_${_getToday()}';
  }

  // ── CSV Generation ─────────────────────────────────────────────────
  String _buildCsvContent(List<Map<String, dynamic>> records,
      {bool includeDeptColumn = false}) {
    final buffer = StringBuffer();
    final headers = [
      'SL NO',
      if (includeDeptColumn) 'DEPARTMENT',
      'STUDENT NAME',
      'USN',
      'EMAIL',
      'COMPANY',
      'DRIVE',
      'ATTENDANCE STATUS',
      'ATTENDANCE DATE',
      'ATTENDANCE TIME',
    ];
    buffer.writeln(headers.join(','));

    for (int i = 0; i < records.length; i++) {
      final rec = records[i];
      final profile = rec['profile'] as Map<String, dynamic>? ?? {};
      final name = _escapeCsv(profile['name'] as String? ?? 'N/A');
      final usn = _escapeCsv(profile['usn'] as String? ?? 'N/A');
      final email = _escapeCsv(profile['email'] as String? ?? 'N/A');
      final dept = profile['department'] as String? ?? 'N/A';
      final status = (rec['status'] as String? ?? 'present').toUpperCase();
      final scannedAt = rec['scanned_at'] as String?;
      final dt = scannedAt != null ? DateTime.tryParse(scannedAt)?.toLocal() : null;
      final dateStr = dt != null
          ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
          : 'N/A';
      final timeStr = dt != null
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : 'N/A';

      final row = [
        '${i + 1}',
        if (includeDeptColumn) _escapeCsv(dept),
        name,
        usn,
        email,
        _escapeCsv(widget.companyName),
        _escapeCsv(widget.roleTitle),
        status,
        dateStr,
        timeStr,
      ];
      buffer.writeln(row.join(','));
    }
    return buffer.toString();
  }

  Future<void> _exportCsv(List<Map<String, dynamic>> records,
      {required String fileName, bool includeDeptColumn = false}) async {
    final csv = _buildCsvContent(records, includeDeptColumn: includeDeptColumn);
    final bytes = utf8.encode(csv);
    await Printing.sharePdf(
      bytes: bytes,
      filename: '$fileName.csv',
    );
  }

  // ── PDF Generation ─────────────────────────────────────────────────
  pw.Document _buildPdf(List<Map<String, dynamic>> records,
      {bool includeDeptColumn = false, String? title}) {
    final pdf = pw.Document();
    final headers = [
      '#',
      if (includeDeptColumn) 'Dept',
      'Student Name',
      'USN',
      'Company',
      'Drive',
      'Status',
      'Date',
      'Time',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MALNAD COLLEGE OF ENGINEERING, HASSAN',
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Training & Placement Office - Attendance Report',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Text(title ?? 'ATTENDANCE REPORT',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Company: ${widget.companyName}',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('Role: ${widget.roleTitle}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Total: ${records.length}',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Generated: ${_getToday()}',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 8),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            data: records.asMap().entries.map((e) {
              final idx = e.key + 1;
              final rec = e.value;
              final profile = rec['profile'] as Map<String, dynamic>? ?? {};
              final name = profile['name'] as String? ?? 'N/A';
              final usn = profile['usn'] as String? ?? 'N/A';
              final dept = profile['department'] as String? ?? 'N/A';
              final status = (rec['status'] as String? ?? 'present').toUpperCase();
              final scannedAt = rec['scanned_at'] as String?;
              final dt =
                  scannedAt != null ? DateTime.tryParse(scannedAt)?.toLocal() : null;
              final dateStr = dt != null
                  ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
                  : 'N/A';
              final timeStr = dt != null
                  ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                  : 'N/A';

              return [
                '$idx',
                if (includeDeptColumn) dept,
                name,
                usn,
                widget.companyName,
                widget.roleTitle,
                status,
                dateStr,
                timeStr,
              ];
            }).toList(),
            rowDecoration: const pw.BoxDecoration(
                border:
                    pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
          ),
        ],
      ),
    );
    return pdf;
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> records,
      {required String fileName, String? title}) async {
    final pdf = _buildPdf(records, title: title);
    final bytes = await pdf.save();

    final directory = await getTemporaryDirectory();
    final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
    final filePath = '${directory.path}/$cleanFileName.pdf';
    await File(filePath).writeAsBytes(bytes);

    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: title ?? 'Drive Attendance Report PDF',
        subject: '$fileName PDF',
      );
    } catch (_) {
      await Printing.sharePdf(bytes: bytes, filename: '$fileName.pdf');
    }
  }

  // ── Main Export Handler ────────────────────────────────────────────
  Future<void> _handleExport() async {
    if (_selectedDepartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one department.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final filtered = _filterRecords(widget.records);
      if (filtered.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No attendance records found for the selected department(s).'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orangeAccent,
            ),
          );
          setState(() => _isExporting = false);
        }
        return;
      }

      final isAllDepts =
          _selectedDepartments.length == _availableDepartments.length;
      final deptLabel = isAllDepts ? 'All_Departments' : _selectedDepartments.join('_');

      // ── CSV ──────────────────────────────────────────────────────
      if (_format == ExportFormat.csv || _exportType == ExportType.both) {
        if (_exportType == ExportType.departmentWise ||
            _exportType == ExportType.both) {
          final grouped = _groupByDept(filtered);
          for (final entry in grouped.entries) {
            await _exportCsv(
              entry.value,
              fileName: 'Attendance_${_deptFileName(entry.key)}',
              includeDeptColumn: false,
            );
          }
        }
        if (_exportType == ExportType.combined ||
            _exportType == ExportType.both) {
          await _exportCsv(
            filtered,
            fileName: 'Attendance_${deptLabel}_${_getToday()}',
            includeDeptColumn: true,
          );
        }
      }

      // ── PDF ──────────────────────────────────────────────────────
      if (_format == ExportFormat.pdf || _exportType == ExportType.both) {
        if (_exportType == ExportType.departmentWise ||
            _exportType == ExportType.both) {
          final grouped = _groupByDept(filtered);
          for (final entry in grouped.entries) {
            await _exportPdf(
              entry.value,
              fileName: 'Attendance_${_deptFileName(entry.key)}',
              title: 'ATTENDANCE — ${entry.key.toUpperCase()}',
            );
          }
        }
        if (_exportType == ExportType.combined ||
            _exportType == ExportType.both) {
          await _exportPdf(
            filtered,
            fileName: 'Attendance_${deptLabel}_${_getToday()}',
            title: 'ATTENDANCE — ALL DEPARTMENTS',
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Exported ${filtered.length} record(s) successfully.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade600,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Build UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandTheme = theme.extension<AppBrandTheme>()!;
    final accent = brandTheme.brassPrimary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: brandTheme.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Icon(Icons.file_download_rounded, color: accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Export Attendance',
                    style: GoogleFonts.fraunces(
                        fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '${widget.records.length} total record(s) from ${widget.companyName}',
              style:
                  GoogleFonts.inter(fontSize: 12, color: brandTheme.textMuted),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section: Department Filter ────────────────────
                  _sectionHeader('DEPARTMENT FILTER', accent),
                  const SizedBox(height: 8),
                  _buildDepartmentFilter(brandTheme),

                  const SizedBox(height: 20),

                  // ── Section: Export Format ────────────────────────
                  _sectionHeader('EXPORT FORMAT', accent),
                  const SizedBox(height: 8),
                  _buildFormatSelector(brandTheme, accent),

                  const SizedBox(height: 20),

                  // ── Section: Export Type ──────────────────────────
                  _sectionHeader('EXPORT TYPE', accent),
                  const SizedBox(height: 8),
                  _buildTypeSelector(brandTheme, accent),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── Export Button ───────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _handleExport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: accent.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    _isExporting
                        ? 'Generating...'
                        : 'Export ${_format == ExportFormat.csv ? 'CSV' : 'PDF'}',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Header ─────────────────────────────────────────────────
  Widget _sectionHeader(String title, Color accent) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: accent,
        letterSpacing: 1.2,
      ),
    );
  }

  // ── Department Filter ──────────────────────────────────────────────
  Widget _buildDepartmentFilter(AppBrandTheme brandTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brandTheme.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select All / Deselect All
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDepartments = Set.from(_availableDepartments);
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandTheme.brassPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Select All',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: brandTheme.brassPrimary)),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDepartments.clear();
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandTheme.cardBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text('Deselect All',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: brandTheme.textMuted)),
                ),
              ),
              Text(
                '${_selectedDepartments.length}/${_availableDepartments.length}',
                style: GoogleFonts.ibmPlexMono(
                    fontSize: 11, color: brandTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Department checkboxes
          ..._availableDepartments.map((dept) {
            final isSelected = _selectedDepartments.contains(dept);
            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDepartments.remove(dept);
                  } else {
                    _selectedDepartments.add(dept);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 20,
                      color: isSelected
                          ? brandTheme.brassPrimary
                          : brandTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(dept,
                          style: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Format Selector ────────────────────────────────────────────────
  Widget _buildFormatSelector(AppBrandTheme brandTheme, Color accent) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: brandTheme.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _formatOption(
              label: 'CSV',
              icon: Icons.table_chart_rounded,
              isSelected: _format == ExportFormat.csv,
              color: Colors.green,
              onTap: () => setState(() => _format = ExportFormat.csv),
              brandTheme: brandTheme,
            ),
          ),
          Expanded(
            child: _formatOption(
              label: 'PDF',
              icon: Icons.picture_as_pdf_rounded,
              isSelected: _format == ExportFormat.pdf,
              color: Colors.redAccent,
              onTap: () => setState(() => _format = ExportFormat.pdf),
              brandTheme: brandTheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    required AppBrandTheme brandTheme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: color.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : brandTheme.textMuted),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : brandTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── Type Selector ──────────────────────────────────────────────────
  Widget _buildTypeSelector(AppBrandTheme brandTheme, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: brandTheme.surfaceAlt.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brandTheme.cardBorder),
      ),
      child: Column(
        children: [
          _typeOption(
            title: 'Department-wise',
            subtitle: 'One file per selected department',
            icon: Icons.folder_open_rounded,
            value: ExportType.departmentWise,
            brandTheme: brandTheme,
            accent: accent,
          ),
          const SizedBox(height: 4),
          _typeOption(
            title: 'Combined',
            subtitle: 'Single file with all departments',
            icon: Icons.merge_rounded,
            value: ExportType.combined,
            brandTheme: brandTheme,
            accent: accent,
          ),
          const SizedBox(height: 4),
          _typeOption(
            title: 'Both',
            subtitle: 'Individual files + combined master file',
            icon: Icons.copy_all_rounded,
            value: ExportType.both,
            brandTheme: brandTheme,
            accent: accent,
          ),
        ],
      ),
    );
  }

  Widget _typeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required ExportType value,
    required AppBrandTheme brandTheme,
    required Color accent,
  }) {
    final isSelected = _exportType == value;
    return InkWell(
      onTap: () => setState(() => _exportType = value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: accent.withValues(alpha: 0.25))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? accent : brandTheme.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: brandTheme.textMuted)),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: isSelected ? accent : brandTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
