// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserProfileModelImpl _$$UserProfileModelImplFromJson(
        Map<String, dynamic> json) =>
    _$UserProfileModelImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      full_name: json['full_name'] as String,
      department: json['department'] as String?,
      cgpa: (json['cgpa'] as num?)?.toDouble(),
      avatar_url: json['avatar_url'] as String?,
      isEmailVerified: json['is_email_verified'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$UserProfileModelImplToJson(
        _$UserProfileModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'role': _$UserRoleEnumMap[instance.role]!,
      'full_name': instance.full_name,
      'department': instance.department,
      'cgpa': instance.cgpa,
      'avatar_url': instance.avatar_url,
      'is_email_verified': instance.isEmailVerified,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$UserRoleEnumMap = {
  UserRole.admin: 'admin',
  UserRole.tpo: 'tpo',
  UserRole.facultyCoordinator: 'facultyCoordinator',
  UserRole.student: 'student',
};
