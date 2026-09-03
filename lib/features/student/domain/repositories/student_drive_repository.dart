import '../entities/drive.dart';

abstract class StudentDriveRepository {
  Future<List<Drive>> getEligibleDrives();
}