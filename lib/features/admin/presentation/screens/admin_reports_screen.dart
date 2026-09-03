import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/admin_provider.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  Future<void> _exportToPdf(List<Map<String, dynamic>> stats) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Institution Placement Report (NAAC/NBA)',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  context: context,
                  headers: ['Department', 'Total Students', 'Attended Drives', 'Total Placed', 'Placement %'],
                  data: stats.map((stat) {
                    final placed = (stat['total_placed'] ?? 0) as int;
                    final students = (stat['total_students'] ?? 1) as int;
                    final pct = students > 0 ? ((placed / students) * 100).toStringAsFixed(1) : '0.0';
                    return [
                      stat['department'] ?? 'General',
                      '${stat['total_students'] ?? 0}',
                      '${stat['total_attended'] ?? 0}',
                      '${stat['total_placed'] ?? 0}',
                      '$pct%',
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/Placement_Report.pdf';
      await File(filePath).writeAsBytes(bytes);

      try {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Institution Placement Report (PDF)',
          subject: 'Placement Report PDF',
        );
      } catch (_) {
        await Printing.sharePdf(bytes: bytes, filename: 'Placement_Report.pdf');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  Future<void> _exportToExcel(List<Map<String, dynamic>> stats) async {
    final excel = Excel.createExcel();
    final sheet = excel['Placement Stats'];
    excel.setDefaultSheet(sheet.sheetName);
    sheet.appendRow([
      TextCellValue('Department'),
      TextCellValue('Total Students'),
      TextCellValue('Attended Drives'),
      TextCellValue('Total Placed'),
      TextCellValue('Placement %'),
    ]);
    for (final stat in stats) {
      final placed = (stat['total_placed'] ?? 0) as int;
      final students = (stat['total_students'] ?? 1) as int;
      final pct = students > 0 ? ((placed / students) * 100).toStringAsFixed(1) : '0.0';
      sheet.appendRow([
        TextCellValue((stat['department'] ?? 'General').toString()),
        IntCellValue((stat['total_students'] ?? 0) as int),
        IntCellValue((stat['total_attended'] ?? 0) as int),
        IntCellValue((stat['total_placed'] ?? 0) as int),
        TextCellValue('$pct%'),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      try {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/Placement_Report.xlsx';
        await File(filePath).writeAsBytes(fileBytes, flush: true);
        final result = await Share.shareXFiles(
          [XFile(filePath, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
          text: 'Institution Placement Report (Excel)',
          subject: 'Placement Report Excel Export',
        );
        if (mounted && result.status == ShareResultStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Excel report shared successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error sharing Excel: $e')));
        }
      }
    }
  }

  Widget _summaryChip(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: valueColor, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  void _refreshAll() {
    ref.invalidate(complianceReportsProvider);
    ref.invalidate(complianceSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(complianceReportsProvider);
    final summaryAsync = ref.watch(complianceSummaryProvider);

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
          title: const Text('NAAC / NBA Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
            tooltip: 'Refresh Reports',
          ),
        ],
      ),
      body: Column(
        children: [
          // -- Institute-Level Summary Banner --------------------------
          summaryAsync.when(
            data: (summary) => Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade700, Colors.indigo.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Institute Placement Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _summaryChip('Students', '${summary['total_students']}', Colors.white70),
                      _summaryChip('Placed', '${summary['total_placed']}', Colors.greenAccent),
                      _summaryChip('Drives', '${summary['total_drives']}', Colors.amberAccent),
                      _summaryChip('Companies', '${summary['total_companies']}', Colors.cyanAccent),
                      _summaryChip('Rate', '${summary['placement_percentage']}%', Colors.orangeAccent),
                    ],
                  ),
                ],
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // -- Export Buttons -------------------------------------------
          reportsAsync.when(
            data: (stats) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: stats.isEmpty ? null : () => _exportToExcel(stats),
                    icon: const Icon(Icons.table_chart, color: Colors.green),
                    label: const Text('Export XLSX'),
                  ),
                  FilledButton.icon(
                    onPressed: stats.isEmpty ? null : () => _exportToPdf(stats),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // -- Per-Department Cards -------------------------------------
          Expanded(
            child: reportsAsync.when(
              data: (stats) {
                if (stats.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No student data found.',
                            style: TextStyle(color: Colors.grey)),

                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshAll(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: stats.length,
                    itemBuilder: (context, index) {
                      final stat = stats[index];
                      final placed = (stat['total_placed'] ?? 0) as int;
                      final students = (stat['total_students'] ?? 0) as int;
                      final attended = (stat['total_attended'] ?? 0) as int;
                      final pct = students > 0 ? (placed / students) * 100 : 0.0;
                      final pctStr = pct.toStringAsFixed(1);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      stat['department'] ?? 'Department',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: pct >= 75
                                          ? Colors.green.shade100
                                          : pct >= 50
                                              ? Colors.orange.shade100
                                              : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$pctStr%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: pct >= 75
                                            ? Colors.green.shade700
                                            : pct >= 50
                                                ? Colors.orange.shade700
                                                : Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: students > 0 ? placed / students : 0,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    pct >= 75
                                        ? Colors.green
                                        : pct >= 50
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.spaceAround,
                                spacing: 24,
                                runSpacing: 8,
                                children: [
                                  _statPill('Total', '$students',
                                      Colors.blue.shade600),
                                  _statPill('Attended', '$attended',
                                      Colors.purple.shade600),
                                  _statPill('Placed', '$placed',
                                      Colors.green.shade600),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading reports:\n$err',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refreshAll,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

