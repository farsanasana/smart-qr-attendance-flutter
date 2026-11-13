import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/features/auth/data/models/user_model.dart';

class DemoAccount {
  const DemoAccount({
    required this.user,
    required this.password,
  });

  final UserModel user;
  final String password;
}

/// Demo credentials strictly for local testing & Postman Mock Server fallback.
class DummyUsers {
  DummyUsers._();

  static const List<DemoAccount> accounts = [
    DemoAccount(
      user: UserModel(
        id: 'EMP001',
        name: 'Rahul',
        email: 'rahul@gmail.com',
        role: AppConstants.roleEmployee,
        department: 'Engineering',
        designation: 'Software Engineer',
      ),
      password: '123456',
    ),
    DemoAccount(
      user: UserModel(
        id: 'EMP002',
        name: 'Anjali',
        email: 'anjali@gmail.com',
        role: AppConstants.roleEmployee,
        department: 'Product Design',
        designation: 'UX Designer',
      ),
      password: '123456',
    ),
    DemoAccount(
      user: UserModel(
        id: 'ADM001',
        name: 'Admin User',
        email: 'admin@gmail.com',
        role: AppConstants.roleAdmin,
        department: 'People Operations',
        designation: 'Attendance Administrator',
      ),
      password: 'admin123',
    ),
  ];

  static List<UserModel> get employeesOnly => accounts
      .where((a) => a.user.role == AppConstants.roleEmployee)
      .map((a) => a.user)
      .toList();

  /// Resolves an identifier (either email or Employee ID like EMP001/ADM001)
  /// to the standard registered email address.
  static String resolveEmail(String identifier) {
    final trimmed = identifier.trim();
    if (trimmed.contains('@')) return trimmed;
    final normalized = trimmed.toLowerCase();
    for (final account in accounts) {
      if (account.user.id.toLowerCase() == normalized) {
        return account.user.email;
      }
    }
    return trimmed;
  }

  static DemoAccount? authenticate(String identifier, String password) {
    final normalized = identifier.trim().toLowerCase();
    for (final account in accounts) {
      final matchesEmail = account.user.email.toLowerCase() == normalized;
      final matchesId = account.user.id.toLowerCase() == normalized;
      if ((matchesEmail || matchesId) && account.password == password) {
        return account;
      }
    }
    return null;
  }
}

