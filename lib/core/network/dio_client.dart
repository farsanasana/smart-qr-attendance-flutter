import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:newwone/core/config/api_config.dart';
import 'package:newwone/core/network/api_exception.dart';

/// Reusable Dio HTTP client with configurable base URL, timeouts,
/// debug-only request/response logging, and centralized error mapping.
class DioClient {
  DioClient({
    Dio? dio,
    String? baseUrl,
  })  : _effectiveBaseUrl = baseUrl ?? ApiConfig.baseUrl,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl:
                    ApiConfig.isConfiguredUrl(baseUrl ?? ApiConfig.baseUrl)
                        ? (baseUrl ?? ApiConfig.baseUrl)
                        : 'https://YOUR-POSTMAN-MOCK-ID.mock.pstmn.io',
                connectTimeout: ApiConfig.connectTimeout,
                receiveTimeout: ApiConfig.receiveTimeout,
                sendTimeout: kIsWeb ? null : ApiConfig.sendTimeout,
                headers: const {
                  'Accept': 'application/json',
                },
              ),
            ) {
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint('[DIO] $obj'),
        ),
      );
    }
  }

  final Dio _dio;
  final String _effectiveBaseUrl;
  final StreamController<ApiException> _unauthorizedController =
      StreamController<ApiException>.broadcast();
  String? _authToken;

  /// Broadcast stream of 401/403 API failures so [AuthenticationBloc]
  /// can expire active sessions when a protected endpoint rejects the token.
  Stream<ApiException> get unauthorizedEvents => _unauthorizedController.stream;

  void close() {
    if (!_unauthorizedController.isClosed) {
      _unauthorizedController.close();
    }
  }

  void setAuthToken(String? token) {
    _authToken = token;
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  String? get authToken => _authToken;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    _ensureMockConfigured();
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    _ensureMockConfigured();
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  void _ensureMockConfigured() {
    if (!ApiConfig.isConfiguredUrl(_effectiveBaseUrl)) {
      throw const ApiException(
        type: ApiErrorType.unconfiguredMock,
        message:
            'Postman Mock Server URL is not configured (or running in demo mode). Saved locally via SQLite.',
      );
    }
  }

  ApiException _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          type: ApiErrorType.timeout,
          message:
              'Request timed out while contacting the server. Please check your connection and retry.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          type: ApiErrorType.noInternet,
          message:
              'No internet connection or server unreachable. Data is safely preserved locally.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          type: ApiErrorType.cancelled,
          message: 'Request was cancelled.',
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          type: ApiErrorType.serverError,
          message: 'SSL certificate verification failed.',
        );
      case DioExceptionType.badResponse:
        return _mapStatusCode(error.response);
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return const ApiException(
            type: ApiErrorType.noInternet,
            message:
                'Network unavailable. Please verify Wi-Fi or mobile data connectivity.',
          );
        }
        return ApiException(
          type: ApiErrorType.unknown,
          message: error.message ?? 'An unexpected network error occurred.',
        );
    }
  }

  ApiException _mapStatusCode(Response<dynamic>? response) {
    final code = response?.statusCode ?? 0;
    final serverMessage = _extractMessage(response?.data);

    if (code == 401 || code == 403) {
      final exception = ApiException(
        statusCode: code,
        type: ApiErrorType.unauthorized,
        message: serverMessage ??
            (code == 403
                ? 'Access forbidden (403). Your account lacks permission or session expired.'
                : 'Unauthorized request (401). Please sign in again.'),
        details: response?.data,
      );
      if (!_unauthorizedController.isClosed) {
        _unauthorizedController.add(exception);
      }
      return exception;
    }
    if (code == 400 || code == 422) {
      return ApiException(
        statusCode: code,
        type: ApiErrorType.badRequest,
        message: serverMessage ?? 'Invalid request payload ($code).',
        details: response?.data,
      );
    }
    if (code == 404) {
      return ApiException(
        statusCode: code,
        type: ApiErrorType.notFound,
        message: serverMessage ?? 'Requested mock endpoint not found (404).',
        details: response?.data,
      );
    }
    if (code >= 500) {
      return ApiException(
        statusCode: code,
        type: ApiErrorType.serverError,
        message:
            serverMessage ?? 'Server error ($code). Please try again shortly.',
        details: response?.data,
      );
    }
    return ApiException(
      statusCode: code,
      type: ApiErrorType.unknown,
      message: serverMessage ?? 'HTTP error ($code).',
      details: response?.data,
    );
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final msg = data['message'] ?? data['error'] ?? data['detail'];
      if (msg is String && msg.trim().isNotEmpty) return msg;
    }
    return null;
  }
}

