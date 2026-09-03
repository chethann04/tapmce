/// Represents an official UG Course / Program from the centralized `courses` master table.
class Course {
  final String id;
  final String courseName;
  final String courseCode;
  final String category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Course({
    required this.id,
    required this.courseName,
    required this.courseCode,
    required this.category,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: (map['id'] as String?) ?? '',
      courseName: (map['course_name'] as String?) ?? 'Unknown Course',
      courseCode: (map['course_code'] as String?) ?? '??',
      category: (map['category'] as String?) ?? 'General Engineering',
      isActive: map['is_active'] as bool? ?? true,
      createdAt: _parseTimestamp(map['created_at']),
      updatedAt: _parseTimestamp(map['updated_at']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value as String);
    } catch (_) {
      return DateTime.now();
    }
  }

  Map<String, dynamic> toMap() => {
        'course_name': courseName,
        'course_code': courseCode,
        'category': category,
        'is_active': isActive,
      };

  Course copyWith({
    String? id,
    String? courseName,
    String? courseCode,
    String? category,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
