/// Application-wide constants and demo credentials.
///
/// SECURITY NOTE:
/// Credentials and client-side QR validation in this module are strictly for
/// demonstration and Postman Mock Server simulation. Production deployments
/// must verify credentials, JWTs, and QR session tokens on a trusted backend.
class AppConstants {
  AppConstants._();

  static const String appName = 'Smart Attendance';
  static const String appTagline = 'Enterprise QR & Geo-Verified Workforce Tracking';

  // SharedPreferences keys
  static const String prefAuthTokenKey = 'auth_token';
  static const String prefCurrentUserKey = 'current_user_json';
  static const String prefActiveQrSessionsKey = 'active_qr_sessions_json';

  // Attendance business rules
  static const int workStartHour = 9;
  static const int workStartMinute = 30; // Arrivals after 09:30 AM marked Late
  static const int defaultQrExpiryMinutes = 5;
  static const List<int> qrExpiryOptionsMinutes = [1, 2, 5, 10, 15];

  // Sync statuses (strictly distinguish local-only vs server-confirmed)
  static const String syncServerConfirmed = 'server_confirmed';
  static const String syncLocalPending = 'local_pending';

  // Attendance types
  static const String typeCheckIn = 'check_in';
  static const String typeCheckOut = 'check_out';

  // Attendance statuses
  static const String statusPresent = 'present';
  static const String statusLate = 'late';
  static const String statusAbsent = 'absent';
  static const String statusCheckedOut = 'checked_out';

  // Roles
  static const String roleEmployee = 'employee';
  static const String roleAdmin = 'admin';
}

