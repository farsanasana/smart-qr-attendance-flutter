import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:newwone/core/config/api_config.dart';
import 'package:newwone/core/network/api_exception.dart';
import 'package:newwone/core/network/dio_client.dart';
import 'package:newwone/features/auth/data/datasources/dummy_users.dart';
import 'package:newwone/features/auth/data/models/user_model.dart';

/// REST API service for authentication endpoints.
class AuthApiService {
  const AuthApiService(this._client);

  final DioClient _client;

  /// Calls `POST /login` with email and password strictly matching Postman mock request body.
  Future<({UserModel user, String token})> login({
    required String identifier,
    required String password,
  }) async {
    final email = DummyUsers.resolveEmail(identifier);
    final requestData = <String, dynamic>{
      'email': email,
      'password': password,
    };

    if (kDebugMode) {
      debugPrint(
        '[AUTH_DEBUG] POST /login request: url=${_client.baseUrl}${ApiConfig.loginEndpoint}, headers={Accept: application/json, Content-Type: application/json}, body=$requestData',
      );
    }

    final response = await _client.post<dynamic>(
      ApiConfig.loginEndpoint,
      data: requestData,
    );

    if (kDebugMode) {
      debugPrint(
        '[AUTH_DEBUG] POST /login response status=${response.statusCode}, body=${response.data}',
      );
    }

    final body = _parseResponseMap(response.data);
    if (body == null || body.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.serverError,
        statusCode: 200,
        message:
            'Authentication server returned an empty response. Verify the POST /login mock example body.',
      );
    }

    final rawUser = body['user'] ?? body['data'] ?? body;
    if (rawUser is! Map<String, dynamic> || rawUser.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.serverError,
        statusCode: 200,
        message:
            'Authentication server response is missing user profile details.',
      );
    }

    final user = UserModel.fromJson(rawUser);
    if (user.id.trim().isEmpty ||
        (user.email.trim().isEmpty && user.name.trim().isEmpty)) {
      throw const ApiException(
        type: ApiErrorType.serverError,
        statusCode: 200,
        message:
            'Authentication server returned an invalid user object (missing id/email).',
      );
    }

    final token = (body['token'] ?? body['access_token'] ?? '').toString().trim();
    if (token.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.serverError,
        statusCode: 200,
        message: 'Authentication server response is missing an access token.',
      );
    }

    return (
      user: user,
      token: token,
    );
  }

  Map<String, dynamic>? _parseResponseMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

