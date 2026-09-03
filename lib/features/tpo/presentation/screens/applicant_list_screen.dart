import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../../../../shared/presentation/widgets/subtle_divider.dart';

class ApplicantListScreen extends ConsumerStatefulWidget {
  const ApplicantListScreen({super.key});

  @override
  ConsumerState<ApplicantListScreen> createState() => _ApplicantListScreenState();
}

class _ApplicantListScreenState extends ConsumerState<ApplicantListScreen> {
  // Mock data representing applicants
  final List<Map<String, dynamic>> _applicants = [
    {'usn': '4MC23IS001', 'name': 'John Doe', 'status': 'Applied'},
    {'usn': '4MC23IS002', 'name': 'Jane Smith', 'status': 'Applied'},
    {'usn': '4MC23IS003', 'name': 'Alice Johnson', 'status': 'Shortlisted'},
  ];

  bool _isUploading = false;

  Future<void> _uploadShortlistCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isUploading = true);
        
        final bytes = result.files.single.bytes!;
        final csvString = utf8.decode(bytes);
        final rows = const CsvToListConverter().convert(csvString);

        if (rows.isNotEmpty) {
          // Assuming CSV format: USN, Status
          // Skip header row if exists
          int startIndex = rows.first.contains('USN') ? 1 : 0;
          
          for (int i = startIndex; i < rows.length; i++) {
            final row = rows[i];
            if (row.length >= 2) {
              final usn = row[0].toString().trim();
              final status = row[1].toString().trim();
              
              // Update mock local state
              final index = _applicants.indexWhere((a) => a['usn'] == usn);
              if (index != -1) {
                _applicants[index]['status'] = status;
              }
            }
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Shortlist updated successfully from CSV!')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing CSV: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _exportApplicantsCsv() {
    List<List<dynamic>> rows = [
      ['USN', 'Name', 'Status'],
      ..._applicants.map((a) => [a['usn'], a['name'], a['status']])
    ];
    final csvData = const ListToCsvConverter().convert(rows);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📥 Exported ${_applicants.length} applicants (${csvData.length} bytes) to CSV!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/tpo');
              }
            },
          ),
          title: const Text('Drive Applicants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Applicants CSV',
            onPressed: _exportApplicantsCsv,
          ),
          IconButton(
            icon: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file),
            tooltip: 'Upload CSV Shortlist',
            onPressed: _isUploading ? null : _uploadShortlistCsv,
          )
        ],
      ),
      body: _applicants.isEmpty
          ? const Center(child: Text('No applicants for this drive yet.'))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Upload a CSV with columns [USN, Status] to bulk update applicant stages (e.g., Shortlisted, Interview).',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _applicants.length,
                    separatorBuilder: (_, __) => const SubtleDivider(height: 1),
                    itemBuilder: (context, index) {
                      final app = _applicants[index];
                      Color statusColor;
                      switch (app['status'].toString().toLowerCase()) {
                        case 'shortlisted':
                        case 'selected':
                          statusColor = Colors.green;
                          break;
                        case 'rejected':
                          statusColor = Colors.red;
                          break;
                        default:
                          statusColor = Colors.blue;
                      }

                      return ListTile(
                        leading: CircleAvatar(child: Text(app['name'].substring(0, 1))),
                        title: Text(app['name']),
                        subtitle: Text(app['usn']),
                        trailing: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Chip(
                            padding: EdgeInsets.zero,
                            label: Text(
                              app['status'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            ),
                            backgroundColor: statusColor,
                          ),
                        ),
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

