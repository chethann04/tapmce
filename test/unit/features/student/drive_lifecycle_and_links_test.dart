import 'package:flutter_test/flutter_test.dart';
import 'package:placement_connect/features/auth/domain/entities/user_profile.dart';
import 'package:placement_connect/features/student/domain/entities/drive.dart';

void main() {
  group('Drive Lifecycle Tests', () {
    test('Calculates isUpcoming correctly when status is upcoming or startDate is in the future', () {
      final upcomingByStatus = Drive(
        id: 'd-1',
        companyId: 'c-1',
        companyName: 'Google',
        roleTitle: 'Software Engineer',
        ctcOrStipend: '25 LPA',
        jobDescription: 'Software Engineer',
        applicationDeadline: DateTime.now().add(const Duration(days: 10)),
        cgpaCutoff: 8.0,
        backlogLimit: 0,
        eligibilityBranches: ['CS', 'IS'],
        status: 'upcoming',
        roundsCount: 4,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(upcomingByStatus.isUpcoming, isTrue);
      expect(upcomingByStatus.isActive, isFalse);
      expect(upcomingByStatus.isClosed, isFalse);

      final upcomingByDate = Drive(
        id: 'd-2',
        companyId: 'c-2',
        companyName: 'Microsoft',
        roleTitle: 'SDE-1',
        ctcOrStipend: '22 LPA',
        jobDescription: 'SDE-1',
        applicationDeadline: DateTime.now().add(const Duration(days: 10)),
        cgpaCutoff: 7.5,
        backlogLimit: 0,
        eligibilityBranches: ['CS', 'IS', 'EC'],
        status: 'open',
        roundsCount: 3,
        startDate: DateTime.now().add(const Duration(days: 2)),
      );

      expect(upcomingByDate.isUpcoming, isTrue);
      expect(upcomingByDate.isActive, isFalse);
    });

    test('Calculates isActive correctly when open and deadline in future', () {
      final activeDrive = Drive(
        id: 'd-3',
        companyId: 'c-3',
        companyName: 'Amazon',
        roleTitle: 'SDE',
        ctcOrStipend: '28 LPA',
        jobDescription: 'SDE',
        applicationDeadline: DateTime.now().add(const Duration(days: 5)),
        cgpaCutoff: 8.0,
        backlogLimit: 0,
        eligibilityBranches: ['CS'],
        status: 'active',
        roundsCount: 3,
        startDate: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(activeDrive.isUpcoming, isFalse);
      expect(activeDrive.isActive, isTrue);
      expect(activeDrive.isClosed, isFalse);
      expect(activeDrive.isDeleted, isFalse);
    });

    test('Auto-closes when deadline has passed (less than 1 week)', () {
      final pastDeadlineDrive = Drive(
        id: 'd-4',
        companyId: 'c-4',
        companyName: 'Infosys',
        roleTitle: 'System Engineer',
        ctcOrStipend: '9 LPA',
        jobDescription: 'SE',
        applicationDeadline: DateTime.now().subtract(const Duration(days: 2)),
        cgpaCutoff: 6.5,
        backlogLimit: 0,
        eligibilityBranches: ['CS', 'IS', 'EC'],
        status: 'active',
        roundsCount: 2,
      );

      expect(pastDeadlineDrive.isClosed, isTrue);
      expect(pastDeadlineDrive.isActive, isFalse);
      expect(pastDeadlineDrive.isDeleted, isFalse);
    });

    test('Auto-deletes when deadline passed more than 1 week (7 days) ago', () {
      final expiredDrive = Drive(
        id: 'd-5',
        companyId: 'c-5',
        companyName: 'TCS',
        roleTitle: 'Ninja',
        ctcOrStipend: '7 LPA',
        jobDescription: 'Developer',
        applicationDeadline: DateTime.now().subtract(const Duration(days: 8)),
        cgpaCutoff: 6.0,
        backlogLimit: 1,
        eligibilityBranches: ['CS', 'EC', 'ME'],
        status: 'completed',
        roundsCount: 2,
      );

      expect(expiredDrive.isClosed, isTrue);
      expect(expiredDrive.isDeleted, isTrue);
      expect(expiredDrive.isActive, isFalse);
    });
  });

  group('UserProfile Professional Links Tests', () {
    test('Serializes and deserializes linkedinUrl and githubUrl correctly', () {
      final user = UserProfile(
        id: 'u-100',
        email: 'student@mce.edu',
        name: 'Rahul Sharma',
        role: UserRole.student,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        linkedinUrl: 'https://linkedin.com/in/rahulsharma',
        githubUrl: 'https://github.com/rahulsharma',
      );

      final map = user.toMap();
      expect(map['linkedin_url'], equals('https://linkedin.com/in/rahulsharma'));
      expect(map['github_url'], equals('https://github.com/rahulsharma'));

      final reconstructed = UserProfile.fromMap(map);
      expect(reconstructed.linkedinUrl, equals('https://linkedin.com/in/rahulsharma'));
      expect(reconstructed.githubUrl, equals('https://github.com/rahulsharma'));
    });
  });
}
