import 'package:newwone/features/auth/domain/entities/user_entity.dart';

/// Result returned after login or session restoration.
class AuthSession {
  const AuthSession({
    required this.user,
    required this.token,
    required this.isDemoMode,
  });

  final UserEntity user;
  final String token;
  final bool isDemoMode;
}

/// Authentication repository contract.
abstract class AuthRepository {
  Future<AuthSession> login({
    required String identifier,
    required String password,
  });

  Future<AuthSession?> restoreSession();

  Future<void> logout();
}

