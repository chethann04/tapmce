import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/department.dart';
import '../../domain/repositories/departments_repository.dart';

class DepartmentsRepositoryImpl implements DepartmentsRepository {
  final SupabaseClient _client;

  DepartmentsRepositoryImpl(this._client);

  @override
  Future<List<Department>> fetchAll() async {
    debugPrint('[DepartmentsRepo] Fetching active departments...');
    try {
      final response = await _client
          .from('departments')
          .select('id, name, branch_code, is_active, created_at')
          .eq('is_active', true)
          .order('name');

      final rows = response as List<dynamic>;
      debugPrint('[DepartmentsRepo] Supabase returned ${rows.length} rows');

      if (rows.isNotEmpty) {
        for (final row in rows.take(3)) {
          debugPrint('[DepartmentsRepo]   sample: ${row['name']} (${row['branch_code']})');
        }
      } else {
        debugPrint('[DepartmentsRepo] WARNING: 0 rows returned. Possible causes:');
        debugPrint('[DepartmentsRepo]   - RLS policy blocking access');
        debugPrint('[DepartmentsRepo]   - Table is empty');
        debugPrint('[DepartmentsRepo]   - is_active=false on all rows');
      }

      final departments = rows
          .map((e) => Department.fromMap(e as Map<String, dynamic>))
          .toList();
      debugPrint('[DepartmentsRepo] Parsed ${departments.length} Department objects');
      return departments;
    } catch (e, st) {
      debugPrint('[DepartmentsRepo] ERROR fetching departments: $e');
      debugPrint('[DepartmentsRepo] Stack trace: $st');
      rethrow;
    }
  }

  @override
  Future<Department> create({
    required String name,
    required String branchCode,
  }) async {
    debugPrint('[DepartmentsRepo] Creating department: $name ($branchCode)');
    final response = await _client
        .from('departments')
        .insert({'name': name, 'branch_code': branchCode.toUpperCase()})
        .select()
        .single();
    debugPrint('[DepartmentsRepo] Created department: ${response['id']}');
    return Department.fromMap(response);
  }

  @override
  Future<void> delete(String id) async {
    debugPrint('[DepartmentsRepo] Deleting department: $id');
    await _client.from('departments').delete().eq('id', id);
    debugPrint('[DepartmentsRepo] Deleted department: $id');
  }
}
