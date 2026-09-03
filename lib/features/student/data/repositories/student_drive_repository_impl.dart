import '../../domain/entities/drive.dart';
import '../../domain/repositories/student_drive_repository.dart';
import '../datasources/student_drive_remote_datasource.dart';

class StudentDriveRepositoryImpl implements StudentDriveRepository {
  final StudentDriveRemoteDataSource remoteDataSource;

  StudentDriveRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Drive>> getEligibleDrives() async {
    return remoteDataSource.getEligibleDrives();
  }
}