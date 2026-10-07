import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/drive.dart';

abstract class StudentDriveRemoteDataSource {
  Future<List<Drive>> getEligibleDrives();
}

class StudentDriveRemoteDataSourceImpl implements StudentDriveRemoteDataSource {
  final SupabaseClient supabaseClient;

  StudentDriveRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<List<Drive>> getEligibleDrives() async {
    try {
      final response = await supabaseClient
          .from('drives')
          .select('*, company:companies!company_id(id, name)')
          .order('created_at', ascending: false);
      return (response as List)
          .map((map) => Drive.fromMap(map as Map<String, dynamic>))
          .where((drive) => !drive.isDeleted)
          .toList();
    } catch (e) {
      try {
        final fallback = await supabaseClient
            .from('drives')
            .select('*, companies(name)')
            .order('created_at', ascending: false);
        return (fallback as List)
            .map((map) => Drive.fromMap(map as Map<String, dynamic>))
            .where((drive) => !drive.isDeleted)
            .toList();
      } catch (e2) {
        try {
          final minimalFallback = await supabaseClient
              .from('drives')
              .select('*')
              .order('created_at', ascending: false);
          return (minimalFallback as List)
              .map((map) => Drive.fromMap(map as Map<String, dynamic>))
              .where((drive) => !drive.isDeleted)
              .toList();
        } catch (err) {
          return [];
        }
      }
    }
  }
}