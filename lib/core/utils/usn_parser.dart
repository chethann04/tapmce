import '../../features/admin/domain/entities/course.dart';
import '../../features/admin/domain/entities/department.dart';

/// Parsed breakdown of an institutional University Seat Number (USN).
class ParsedUsn {
  final String raw;
  final String normalized;
  final String regionOrUnivDigit;
  final String collegeCode;
  final int admissionYear;
  final String branchCode;
  final String sequenceNumber;
  final bool isValid;

  const ParsedUsn({
    required this.raw,
    required this.normalized,
    required this.regionOrUnivDigit,
    required this.collegeCode,
    required this.admissionYear,
    required this.branchCode,
    required this.sequenceNumber,
    required this.isValid,
  });

  @override
  String toString() =>
      'ParsedUsn($normalized, College: $collegeCode, Year: $admissionYear, Branch: $branchCode, Seq: $sequenceNumber, Valid: $isValid)';
}

/// Utility for parsing, normalizing, and resolving VTU / MCE University Seat Numbers (USNs).
///
/// Standard USN format:
///   `4 M C 23 I S 0 2 1`
///    ↑ ↑ ↑ ↑↑ ↑ ↑ ↑ ↑ ↑
///    | College Code (e.g. 4MC, 1MC, 4MH, etc.)
///          Year of Admission (2 digits → e.g. 23 = 2023)
///             Branch Code (2–3 letters → e.g. IS, CS, AD, CI, ME)
///                Candidate Sequential Roll Number (3 digits → 021)
class UsnParser {
  UsnParser._();

  /// Regex pattern capturing:
  /// Group 1: Leading digit (e.g. 4 or 1)
  /// Group 2: College 2-letter identifier (e.g. MC)
  /// Group 3: 2-digit admission year (e.g. 23)
  /// Group 4: 2 to 3 letter branch code (e.g. IS, CS, AD, CI, ME)
  /// Group 5: 3+ digit sequential roll number (e.g. 021)
  static final RegExp _usnRegex = RegExp(
    r'^([0-9])([A-Za-z0-9]{2})([0-9]{2})([A-Za-z]{2,3})([0-9]{3,4})$',
  );

  /// Normalizes user input: strips accidental spaces and converts to uppercase.
  /// Example: ` 4mc 23is 021 ` → `4MC23IS021`
  static String normalizeUsn(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), '').toUpperCase().trim();
  }

  /// Returns true if [raw] adheres to the institutional USN structure.
  static bool isValidUsn(String raw) {
    final normalized = normalizeUsn(raw);
    return _usnRegex.hasMatch(normalized);
  }

  /// Parses a raw USN string into its structured parts.
  static ParsedUsn parseUsn(String raw) {
    final normalized = normalizeUsn(raw);
    final match = _usnRegex.firstMatch(normalized);

    if (match == null) {
      return ParsedUsn(
        raw: raw,
        normalized: normalized,
        regionOrUnivDigit: '',
        collegeCode: '',
        admissionYear: 0,
        branchCode: '',
        sequenceNumber: '',
        isValid: false,
      );
    }

    final digit = match.group(1) ?? '';
    final collegeLetters = match.group(2) ?? '';
    final yearStr = match.group(3) ?? '00';
    final branchCode = (match.group(4) ?? '').toUpperCase();
    final seqNum = match.group(5) ?? '';

    final yearTwoDigits = int.tryParse(yearStr) ?? 0;
    // Map 2-digit year to 4-digit century (e.g. 23 → 2023)
    final fullYear = yearTwoDigits >= 50 ? 1900 + yearTwoDigits : 2000 + yearTwoDigits;

    return ParsedUsn(
      raw: raw,
      normalized: normalized,
      regionOrUnivDigit: digit,
      collegeCode: '$digit$collegeLetters',
      admissionYear: fullYear,
      branchCode: branchCode,
      sequenceNumber: seqNum,
      isValid: true,
    );
  }

  /// Extracts the uppercase branch code from [usn]. Returns `null` if invalid.
  static String? extractBranchCode(String usn) {
    final parsed = parseUsn(usn);
    return parsed.isValid ? parsed.branchCode : null;
  }

  /// Resolves the candidate's branch against the centralized master [Course] catalogue.
  static Course? matchCourse(String usn, List<Course> courses) {
    final code = extractBranchCode(usn);
    if (code == null) return null;

    try {
      return courses.firstWhere(
        (c) => c.courseCode.toUpperCase() == code && c.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fallback detector for legacy [Department] list.
  static Department? detectDepartment(
    String usn,
    List<Department> departments,
  ) {
    final code = extractBranchCode(usn);
    if (code == null) return null;

    try {
      return departments.firstWhere(
        (d) => d.branchCode.toUpperCase() == code,
      );
    } catch (_) {
      return null;
    }
  }
}
