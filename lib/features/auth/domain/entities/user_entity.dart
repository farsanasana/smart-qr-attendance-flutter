import 'package:equatable/equatable.dart';
import 'package:newwone/core/constants/app_constants.dart';

/// Authenticated user domain entity.
class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.department = 'Corporate Operations',
    this.designation = 'Staff Member',
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final String designation;

  bool get isAdmin => role.toLowerCase() == AppConstants.roleAdmin;

  @override
  List<Object?> get props => [id, name, email, role, department, designation];
}

