/// Central configuration for REST API integration with Postman Mock Server.
///
/// HOW TO CONFIGURE YOUR POSTMAN MOCK SERVER:
/// 1. Import `postman/Smart_Attendance_Postman_Collection.json` into Postman
///    and link it to your Mock Server so all 7 endpoints return valid JSON.
/// 2. Edit `_defaultBaseUrl` below OR override at build/run time:
///    `flutter run --dart-define=API_BASE_URL=https://your-mock-id.mock.pstmn.io`
///    To force pure offline/local demo mode without HTTP requests, run with:
///    `flutter run --dart-define=API_BASE_URL=demo`
class ApiConfig {
  ApiConfig._();

  static const String _defaultBaseUrl =
      'https://acac5be5-b85b-49a0-8d65-83a0f6c3f812.mock.pstmn.io';

  /// Configurable Base URL. Override via `--dart-define=API_BASE_URL=...`.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  /// Returns true when a real/mock HTTP URL is configured (not `'demo'` or placeholder).
  static bool isConfiguredUrl(String url) {
    final trimmed = url.trim().toLowerCase();
    return trimmed.isNotEmpty &&
        trimmed != 'demo' &&
        !trimmed.contains('your-postman-mock-id');
  }

  static bool get isMockServerConfigured => isConfiguredUrl(baseUrl);

  static const Duration connectTimeout = Duration(seconds: 12);
  static const Duration receiveTimeout = Duration(seconds: 12);
  static const Duration sendTimeout = Duration(seconds: 12);

  // Endpoint paths
  static const String loginEndpoint = '/login';
  static const String attendanceEndpoint = '/attendance';
  static const String checkInEndpoint = '/attendance/check-in';
  static const String checkOutEndpoint = '/attendance/check-out';
  static const String attendanceHistoryEndpoint = '/attendance/history';
  static const String adminQrSessionEndpoint = '/admin/qr-session';
  static const String adminEmployeesEndpoint = '/admin/employees';
}

