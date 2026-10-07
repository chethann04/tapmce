import 'package:flutter_test/flutter_test.dart';
import 'package:placement_connect/features/auth/domain/entities/user_profile.dart';
import 'package:placement_connect/core/utils/usn_parser.dart';

void main() {
  group('Faculty Routing & Role Integrity Tests', () {
    test('Faculty and FacultyCoordinator roles resolve correctly from strings', () {
      expect(UserRole.fromString('faculty'), UserRole.faculty);
      expect(UserRole.fromString('faculty_coordinator'), UserRole.facultyCoordinator);
      expect(UserRole.fromString('FACULTY'), UserRole.faculty);
      expect(UserRole.fromString('FACULTY_COORDINATOR'), UserRole.facultyCoordinator);
    });

    test('Approval status transitions preserve pending, approved, and rejected', () {
      expect(ApprovalStatus.fromString('pending'), ApprovalStatus.pending);
      expect(ApprovalStatus.fromString('approved'), ApprovalStatus.approved);
      expect(ApprovalStatus.fromString('rejected'), ApprovalStatus.rejected);
      expect(ApprovalStatus.fromString('unknown_value'), ApprovalStatus.pending);
    });

    test('UserProfile preserves UUID and department mappings accurately', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'test-uuid-1234',
        role: UserRole.student,
        name: 'John Doe',
        email: 'johndoe@ms.mcehassan.ac.in',
        department: 'Information Science & Engineering',
        usn: '4MC23IS021',
        approvalStatus: ApprovalStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      expect(profile.id, 'test-uuid-1234');
      expect(profile.email, 'johndoe@ms.mcehassan.ac.in');
      expect(profile.department, 'Information Science & Engineering');
      expect(profile.approvalStatus, ApprovalStatus.pending);

      final map = profile.toMap();
      expect(map['id'], 'test-uuid-1234');
      expect(map['role'], 'student');
      expect(map['department'], 'Information Science & Engineering');
      expect(map['approval_status'], 'pending');

      final fromMapProfile = UserProfile.fromMap(map);
      expect(fromMapProfile.id, 'test-uuid-1234');
      expect(fromMapProfile.department, 'Information Science & Engineering');
      expect(fromMapProfile.approvalStatus, ApprovalStatus.pending);
    });
  });

  group('USN Parser & Department Isolation Branch Code Tests', () {
    test('Parses Information Science (IS) branch code from USN', () {
      final parsed = UsnParser.parseUsn('4MC23IS021');
      expect(parsed.isValid, isTrue);
      expect(parsed.branchCode, 'IS');
      expect(parsed.collegeCode, '4MC');
      expect(parsed.admissionYear, 2023);
      expect(parsed.sequenceNumber, '021');
    });

    test('Parses Computer Science (CS) branch code from USN', () {
      final parsed = UsnParser.parseUsn('4MC23CS045');
      expect(parsed.isValid, isTrue);
      expect(parsed.branchCode, 'CS');
      expect(parsed.admissionYear, 2023);
    });

    test('Parses Electronics and Communication (EC) branch code from USN', () {
      final parsed = UsnParser.parseUsn('4MC23EC012');
      expect(parsed.isValid, isTrue);
      expect(parsed.branchCode, 'EC');
    });

    test('Parses Mechanical Engineering (ME) branch code from USN', () {
      final parsed = UsnParser.parseUsn('4MC23ME005');
      expect(parsed.isValid, isTrue);
      expect(parsed.branchCode, 'ME');
    });
  });
}
