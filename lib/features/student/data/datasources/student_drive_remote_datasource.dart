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
    final response = await supabaseClient
        .from('drives')
        .select('*, company:companies(name)');
    return (response as List).map((map) => Drive.fromMap(map)).toList();
  }
}