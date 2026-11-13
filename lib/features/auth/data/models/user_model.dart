import 'dart:convert';

import 'package:newwone/features/auth/domain/entities/user_entity.dart';

/// Serializable user model for REST API and SharedPreferences storage.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    super.department,
    super.designation,
  });

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
      role: entity.role,
      department: entity.department,
      designation: entity.designation,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? json['employee_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'employee').toString(),
      department: (json['department'] ?? 'Corporate Operations').toString(),
      designation: (json['designation'] ?? 'Team Member').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'department': department,
      'designation': designation,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String raw) {
    return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

