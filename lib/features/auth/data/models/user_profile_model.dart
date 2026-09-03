import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/user_profile.dart';

part 'user_profile_model.freezed.dart';
part 'user_profile_model.g.dart';

@freezed
class UserProfileModel with _$UserProfileModel {
  const UserProfileModel._();

  const factory UserProfileModel({
    required String id,
    required String email,
    required UserRole role,
    required String full_name,
    String? department,
    double? cgpa, // ADDED
    String? avatar_url,
    required bool isEmailVerified,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _UserProfileModel;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  UserProfile toDomain() {
    return UserProfile(
      id: id,
      email: email,
      role: role,
      name: full_name,
      department: department,
      cgpa: cgpa,
      photoUrl: avatar_url,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}