import 'package:flutter_test/flutter_test.dart';
import 'package:newwone/core/constants/app_constants.dart';
import 'package:newwone/features/qr_scanner/domain/entities/qr_payload.dart';

void main() {
  group('QrPayload', () {
    test('parses valid check-in QR payload and checks expiry accurately', () {
      final now = DateTime.utc(2026, 11, 12, 9, 0, 0);
      final expires = now.add(const Duration(minutes: 5));

      final payload = QrPayload(
        sessionId: 'SES-20261112-ABC123',
        qrToken: 'Token1234567890ABCD',
        attendanceType: AppConstants.typeCheckIn,
        expiresAt: expires,
        issuedAt: now,
        generatedBy: 'ADM001',
      );

      final parsed = QrPayload.tryParse(payload.toRawPayload());
      expect(parsed, isNotNull);
      expect(parsed!.sessionId, 'SES-20261112-ABC123');
      expect(parsed.qrToken, 'Token1234567890ABCD');
      expect(parsed.isCheckIn, isTrue);
      expect(parsed.isCheckOut, isFalse);
      expect(parsed.isExpiredAt(now.add(const Duration(minutes: 4))), isFalse);
      expect(parsed.isExpiredAt(now.add(const Duration(minutes: 6))), isTrue);
    });

    test('rejects invalid JSON, unknown attendance_type, and short tokens', () {
      expect(QrPayload.tryParse('not json'), isNull);
      expect(QrPayload.tryParse('{}'), isNull);
      expect(
        QrPayload.tryParse(
          '{"session_id":"SES-1","qr_token":"short","attendance_type":"check_in","expires_at":"2026-11-12T10:00:00Z"}',
        ),
        isNull,
      );
      expect(
        QrPayload.tryParse(
          '{"session_id":"SES-1","qr_token":"ValidToken12345","attendance_type":"break_time","expires_at":"2026-11-12T10:00:00Z"}',
        ),
        isNull,
      );
      expect(
        QrPayload.tryParse(
          '{"session_id":"SES-1","qr_token":"ValidToken12345","attendance_type":"check_in","expires_at":"invalid-date"}',
        ),
        isNull,
      );
    });

    test('validates integrity tag and rejects tampered expiry or token', () {
      final now = DateTime.utc(2026, 11, 12, 9, 0, 0);
      final signed = QrPayload(
        sessionId: 'SES-20261112-XYZ123',
        qrToken: 'SecureDemoToken12345',
        attendanceType: AppConstants.typeCheckIn,
        expiresAt: now.add(const Duration(minutes: 5)),
        issuedAt: now,
        generatedBy: 'ADM001',
      ).withIntegrityTag();

      final raw = signed.toRawPayload();
      expect(QrPayload.tryParse(raw), isNotNull);

      // Tamper with expiry timestamp while keeping original signature -> rejected
      final tampered = raw.replaceFirst(
        '2026-11-12T09:05:00.000Z',
        '2099-11-12T09:05:00.000Z',
      );
      expect(QrPayload.tryParse(tampered), isNull);
    });

    test('End-to-End: Admin QR generation to Employee QR scanning validation', () {
      // 1. Admin generates dynamic check-in session at runtime
      final now = DateTime.now().toUtc();
      final adminPayload = QrPayload(
        sessionId: 'SES-LIVE-${now.millisecondsSinceEpoch}',
        qrToken: 'LiveAdminToken987654321',
        attendanceType: AppConstants.typeCheckIn,
        expiresAt: now.add(const Duration(minutes: 10)),
        issuedAt: now,
        generatedBy: 'ADM001',
      ).withIntegrityTag();

      // 2. Encoded into raw QR barcode payload string
      final rawQrBarcode = adminPayload.toRawPayload();

      // 3. Employee scanner receives raw barcode and parses
      final employeeParsed = QrPayload.tryParse(rawQrBarcode);
      expect(employeeParsed, isNotNull);
      expect(employeeParsed!.sessionId, adminPayload.sessionId);
      expect(employeeParsed.qrToken, adminPayload.qrToken);
      expect(employeeParsed.attendanceType, AppConstants.typeCheckIn);
      expect(employeeParsed.isCheckIn, isTrue);
      expect(employeeParsed.isExpiredAt(), isFalse);
      expect(employeeParsed.hasValidIntegrityTag, isTrue);

      // 4. Admin generates Check-Out session
      final adminCheckOut = QrPayload(
        sessionId: 'SES-OUT-${now.millisecondsSinceEpoch}',
        qrToken: 'CheckOutToken123456789',
        attendanceType: AppConstants.typeCheckOut,
        expiresAt: now.add(const Duration(minutes: 15)),
        issuedAt: now,
        generatedBy: 'ADM001',
      ).withIntegrityTag();

      final employeeCheckOut = QrPayload.tryParse(adminCheckOut.toRawPayload());
      expect(employeeCheckOut, isNotNull);
      expect(employeeCheckOut!.isCheckOut, isTrue);
      expect(employeeCheckOut.hasValidIntegrityTag, isTrue);

      // 5. Also parses cross-platform Postman/camelCase payload formats
      final postmanRaw =
          '{"sessionId":"SESSION003","qrToken":"dummy_qr_token_123","attendanceType":"check_in","expiresAt":"2099-01-01T08:05:00Z","generatedBy":"ADM001"}';
      final parsedPostman = QrPayload.tryParse(postmanRaw);
      expect(parsedPostman, isNotNull);
      expect(parsedPostman!.sessionId, 'SESSION003');
      expect(parsedPostman.qrToken, 'dummy_qr_token_123');
      expect(parsedPostman.isCheckIn, isTrue);
    });

    test('Exact User Console Log QR Payload: Check-In & Check-Out validation', () {
      final issuedAt = DateTime.parse('2026-11-12T21:23:27.870Z');
      final expiresAt = DateTime.parse('2026-11-12T21:28:27.870Z');

      // Admin Check-In payload with new cross-platform integrity tag
      final checkInPayload = QrPayload(
        sessionId: 'SES-20261112-QWBJHC',
        qrToken: 'WW6FdAz9a4HVWreQ9Z73ZDaZ',
        attendanceType: AppConstants.typeCheckIn,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        generatedBy: 'ADM001',
      ).withIntegrityTag();

      final checkInRaw = checkInPayload.toRawPayload();
      final parsedCheckIn = QrPayload.tryParse(checkInRaw);

      expect(parsedCheckIn, isNotNull);
      expect(parsedCheckIn!.sessionId, 'SES-20261112-QWBJHC');
      expect(parsedCheckIn.qrToken, 'WW6FdAz9a4HVWreQ9Z73ZDaZ');
      expect(parsedCheckIn.isCheckIn, isTrue);
      expect(parsedCheckIn.isCheckOut, isFalse);
      expect(parsedCheckIn.hasValidIntegrityTag, isTrue);

      // Admin Check-Out payload
      final checkOutPayload = QrPayload(
        sessionId: 'SES-20261112-QWBJHC-OUT',
        qrToken: 'WW6FdAz9a4HVWreQ9Z73ZDaZ',
        attendanceType: AppConstants.typeCheckOut,
        issuedAt: issuedAt,
        expiresAt: expiresAt,
        generatedBy: 'ADM001',
      ).withIntegrityTag();

      final checkOutRaw = checkOutPayload.toRawPayload();
      final parsedCheckOut = QrPayload.tryParse(checkOutRaw);

      expect(parsedCheckOut, isNotNull);
      expect(parsedCheckOut!.sessionId, 'SES-20261112-QWBJHC-OUT');
      expect(parsedCheckOut.isCheckOut, isTrue);
      expect(parsedCheckOut.isCheckIn, isFalse);
      expect(parsedCheckOut.hasValidIntegrityTag, isTrue);

      // Tampering detection: changing attendance_type fails tag verification
      final tamperedType = checkInRaw.replaceFirst('"attendance_type":"check_in"', '"attendance_type":"check_out"');
      expect(QrPayload.tryParse(tamperedType), isNull);

      // Tampering detection: changing session_id fails tag verification
      final tamperedSession = checkInRaw.replaceFirst('SES-20261112-QWBJHC', 'SES-TAMPERED-001');
      expect(QrPayload.tryParse(tamperedSession), isNull);
    });
  });
}

