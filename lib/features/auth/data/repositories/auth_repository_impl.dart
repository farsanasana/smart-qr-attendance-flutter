import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/core/network/api_exception.dart';
import 'package:newwone/core/network/dio_client.dart';
import 'package:newwone/features/auth/data/datasources/auth_api_service.dart';
import 'package:newwone/features/auth/data/datasources/dummy_users.dart';
import 'package:newwone/features/auth/data/models/user_model.dart';
import 'package:newwone/features/auth/domain/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApiService apiService,
    required DioClient dioClient,
    SharedPreferences? preferences,
  })  : _apiService = apiService,
        _dioClient = dioClient,
        _preferences = preferences;

  final AuthApiService _apiService;
  final DioClient _dioClient;
  SharedPreferences? _preferences;

  Future<SharedPreferences> _getPrefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final normalized = identifier.trim().toLowerCase();
    final isKnownAccount = DummyUsers.accounts.any(
      (a) =>
          a.user.email.toLowerCase() == normalized ||
          a.user.id.toLowerCase() == normalized,
    );
    final demoAuth = DummyUsers.authenticate(identifier, password);

    // If this is a recognized demo account but the password was wrong, reject immediately.
    // This prevents a static 200 OK mock server response from logging in with an invalid password.
    if (isKnownAccount && demoAuth == null) {
      throw const ApiException(
        type: ApiErrorType.unauthorized,
        statusCode: 401,
        message:
            'Invalid credentials. Please check your Employee ID / Email and password.',
      );
    }

    try {
      final result = await _apiService.login(
        identifier: identifier,
        password: password,
      );

      final matchesServerUser =
          result.user.id.toLowerCase() == normalized ||
          result.user.email.toLowerCase() == normalized;

      // If the mock server returned a static response (e.g. EMP001 Rahul) while
      // logging in as another valid demo account (e.g. ADM001 Admin or EMP002 Anjali),
      // bind the session to the authenticated demo account while using the active server token.
      final effectiveUser = matchesServerUser
          ? result.user
          : (demoAuth?.user ?? result.user);

      if (!matchesServerUser && demoAuth == null) {
        throw const ApiException(
          type: ApiErrorType.unauthorized,
          statusCode: 401,
          message:
              'Invalid credentials. Please check your Employee ID / Email and password.',
        );
      }

      await _persistSession(user: effectiveUser, token: result.token);
      _dioClient.setAuthToken(result.token);
      return AuthSession(
        user: effectiveUser,
        token: result.token,
        isDemoMode: false,
      );
    } on ApiException catch (e) {
      // Fall back to local dummy credentials on network connectivity failures
      // or when the Postman Mock Server URL is unconfigured.
      if (e.isConnectivityIssue || e.type == ApiErrorType.unconfiguredMock) {
        if (demoAuth != null) {
          final demoToken =
              'demo-${demoAuth.user.id}-${DateTime.now().millisecondsSinceEpoch}';
          await _persistSession(user: demoAuth.user, token: demoToken);
          _dioClient.setAuthToken(demoToken);

          return AuthSession(
            user: demoAuth.user,
            token: demoToken,
            isDemoMode: true,
          );
        }
      }
      rethrow;
    }
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final prefs = await _getPrefs();
    final token = prefs.getString(AppConstants.prefAuthTokenKey);
    final rawUser = prefs.getString(AppConstants.prefCurrentUserKey);
    if (token == null || token.isEmpty || rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      final user = UserModel.fromJsonString(rawUser);
      if (user.id.trim().isEmpty) {
        await logout();
        return null;
      }
      _dioClient.setAuthToken(token);
      return AuthSession(
        user: user,
        token: token,
        isDemoMode: token.startsWith('demo-'),
      );
    } catch (_) {
      await logout();
      return null;
    }
  }

  @override
  Future<void> logout() async {
    _dioClient.setAuthToken(null);
    final prefs = await _getPrefs();
    await prefs.remove(AppConstants.prefAuthTokenKey);
    await prefs.remove(AppConstants.prefCurrentUserKey);
  }

  Future<void> _persistSession({
    required UserModel user,
    required String token,
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(AppConstants.prefAuthTokenKey, token);
    await prefs.setString(
      AppConstants.prefCurrentUserKey,
      user.toJsonString(),
    );
  }
}

