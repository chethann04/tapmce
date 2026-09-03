class Company {
  final String id;
  final String name;
  final String? industry;
  final String? hrContactName;
  final String? hrContactEmail;
  final String? hrContactPhone;
  final DateTime createdAt;

  const Company({
    required this.id,
    required this.name,
    this.industry,
    this.hrContactName,
    this.hrContactEmail,
    this.hrContactPhone,
    required this.createdAt,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      industry: json['industry'] as String?,
      hrContactName: json['hr_contact_name'] as String?,
      hrContactEmail: json['hr_contact_email'] as String?,
      hrContactPhone: json['hr_contact_phone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  factory Company.fromMap(Map<String, dynamic> map) => Company.fromJson(map);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'industry': industry,
      'hr_contact_name': hrContactName,
      'hr_contact_email': hrContactEmail,
      'hr_contact_phone': hrContactPhone,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
