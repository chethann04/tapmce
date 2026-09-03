import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/departments_repository_impl.dart';
import '../../domain/entities/department.dart';
import '../../domain/repositories/departments_repository.dart';

final departmentsRepositoryProvider = Provider<DepartmentsRepository>((ref) {
  return DepartmentsRepositoryImpl(Supabase.instance.client);
});

/// Fetches all active departments from Supabase.
/// Invalidate this provider after create/delete to refresh the list.
final departmentsProvider = FutureProvider<List<Department>>((ref) async {
  debugPrint('[DepartmentsProvider] Loading departments...');
  final repo = ref.watch(departmentsRepositoryProvider);
  try {
    final departments = await repo.fetchAll();
    debugPrint('[DepartmentsProvider] Loaded ${departments.length} departments');
    for (final d in departments) {
      debugPrint('[DepartmentsProvider]   ${d.branchCode} - ${d.name}');
    }
    return departments;
  } catch (e, st) {
    debugPrint('[DepartmentsProvider] ERROR: $e');
    debugPrint('[DepartmentsProvider] Stack: $st');
    rethrow;
  }
});
