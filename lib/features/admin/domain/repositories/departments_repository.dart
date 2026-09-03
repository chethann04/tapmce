import '../../domain/entities/department.dart';

abstract class DepartmentsRepository {
  /// Returns all departments ordered by name.
  Future<List<Department>> fetchAll();

  /// Creates a new department. Returns the created record.
  Future<Department> create({required String name, required String branchCode});

  /// Deletes a department by its id.
  Future<void> delete(String id);
}
