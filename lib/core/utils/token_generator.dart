import 'dart:math';

/// Cryptographically random token and session ID generator for demo QR payloads.
class TokenGenerator {
  TokenGenerator._();

  static final Random _secureRandom = Random.secure();
  static const String _chars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

  /// Generates a session ID such as `SES-20261112-A9F3K2`.
  static String generateSessionId([DateTime? now]) {
    final dt = (now ?? DateTime.now()).toUtc();
    final datePart =
        '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
    final suffix = _randomString(6).toUpperCase();
    return 'SES-$datePart-$suffix';
  }

  /// Generates a 24-character unique QR token.
  static String generateQrToken({int length = 24}) {
    return _randomString(length);
  }

  static String _randomString(int length) {
    return List.generate(
      length,
      (_) => _chars[_secureRandom.nextInt(_chars.length)],
    ).join();
  }
}

