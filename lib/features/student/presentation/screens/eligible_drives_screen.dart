import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/student_drive_provider.dart';

class EligibleDrivesScreen extends ConsumerWidget {
  const EligibleDrivesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivesAsync = ref.watch(studentEligibleDrivesProvider);
    final appliedIds = ref.watch(studentAppliedDriveIdsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/student');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Eligible Placement Drives'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/student');
              }
            },
          ),
        ),
      body: drivesAsync.when(
        data: (drives) {
          if (drives.isEmpty) {
            return const Center(
              child: Text(
                'No eligible drives found.\nMake sure you have opted in and meet the academic criteria.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: drives.length,
            itemBuilder: (context, index) {
              final drive = drives[index];
              final isApplied = appliedIds.contains(drive.id);
              const studentCgpa = 8.4; // Sample logged-in profile CGPA match check
              final isEligible = studentCgpa >= drive.cgpaCutoff;
              final matchScore = isEligible ? 95 : 60;

              return InkWell(
                onTap: () => context.push('/student/drive/${drive.id}', extra: drive),
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              drive.companyName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isEligible ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                '$matchScore% Match · ${isEligible ? "Eligible" : "Near Match"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isEligible ? Colors.greenAccent : Colors.amberAccent,
                                ),
                              ),
                            ),
                            if (isApplied)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 12, color: Colors.greenAccent),
                                    SizedBox(width: 4),
                                    Text(
                                      'Applied',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.greenAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Role: ${drive.roleTitle}'),
                        Text('CTC/Stipend: ${drive.ctcOrStipend}'),
                        Text('Min CGPA: ${drive.cgpaCutoff}'),
                        Text('Deadline: ${drive.applicationDeadline.toLocal().toString().split(' ')[0]}'),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () {
                              context.push('/student/drive/${drive.id}', extra: drive);
                            },
                            child: Text(isApplied ? 'View Details' : 'View & Apply'),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    ),
  );
  }
}
