import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/course.dart';

/// Remote datasource for fetching and managing centralized master courses.
class CourseRemoteDatasource {
  final SupabaseClient _client;
  CourseRemoteDatasource(this._client);

  Future<List<Course>> getCourses({bool activeOnly = true}) async {
    var query = _client.from('courses').select();
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final res = await query.order('course_name', ascending: true);
    return (res as List).map((row) => Course.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<void> addCourse({
    required String courseName,
    required String courseCode,
    required String category,
  }) async {
    await _client.from('courses').insert({
      'course_name': courseName.trim(),
      'course_code': courseCode.trim().toUpperCase(),
      'category': category.trim(),
      'is_active': true,
    });
  }

  Future<void> updateCourse({
    required String id,
    required String courseName,
    required String courseCode,
    required String category,
    required bool isActive,
  }) async {
    await _client.from('courses').update({
      'course_name': courseName.trim(),
      'course_code': courseCode.trim().toUpperCase(),
      'category': category.trim(),
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> toggleCourseStatus(String id, bool isActive) async {
    await _client.from('courses').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}

final courseDatasourceProvider = Provider<CourseRemoteDatasource>((ref) {
  return CourseRemoteDatasource(Supabase.instance.client);
});

final coursesProvider = FutureProvider<List<Course>>((ref) async {
  final ds = ref.watch(courseDatasourceProvider);
  return ds.getCourses(activeOnly: false);
});

final activeCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final ds = ref.watch(courseDatasourceProvider);
  return ds.getCourses(activeOnly: true);
});
