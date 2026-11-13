/// Typed categories for REST API and connectivity failures.
enum ApiErrorType {
  noInternet,
  timeout,
  unauthorized,
  badRequest,
  notFound,
  serverError,
  cancelled,
  unconfiguredMock,
  unknown,
}

/// Exception thrown by [DioClient] and API services with clear user-facing messages.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.type,
    this.statusCode,
    this.details,
  });

  final String message;
  final ApiErrorType type;
  final int? statusCode;
  final dynamic details;

  bool get isConnectivityIssue =>
      type == ApiErrorType.noInternet ||
      type == ApiErrorType.timeout ||
      type == ApiErrorType.unconfiguredMock;

  bool get isUnauthorized => type == ApiErrorType.unauthorized;

  @override
  String toString() => 'ApiException($type, status=$statusCode): $message';
}

