/// Represents a department row from the `departments` table in Supabase.
class Department {
  final String id;
  final String name;
  final String branchCode;
  final bool isActive;
  final DateTime createdAt;

  const Department({
    required this.id,
    required this.name,
    required this.branchCode,
    this.isActive = true,
    required this.createdAt,
  });

  factory Department.fromMap(Map<String, dynamic> map) {
    return Department(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Unknown Department',
      branchCode: (map['branch_code'] as String?) ?? '??',
      isActive: map['is_active'] as bool? ?? true,
      createdAt: _parseTimestamp(map['created_at']),
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
        'name': name,
        'branch_code': branchCode,
        'is_active': isActive,
      };

  Department copyWith({
    String? id,
    String? name,
    String? branchCode,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      branchCode: branchCode ?? this.branchCode,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
