import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:newwone/core/constants/app_constants.dart';

/// Structured payload encoded inside attendance QR codes.
class QrPayload extends Equatable {
  const QrPayload({
    required this.sessionId,
    required this.qrToken,
    required this.attendanceType,
    required this.expiresAt,
    this.issuedAt,
    this.generatedBy,
    this.signature,
  });

  final String sessionId;
  final String qrToken;
  final String attendanceType;
  final DateTime expiresAt;
  final DateTime? issuedAt;
  final String? generatedBy;
  final String? signature;

  bool get isCheckIn => attendanceType == AppConstants.typeCheckIn;
  bool get isCheckOut => attendanceType == AppConstants.typeCheckOut;

  /// Computes a deterministic cross-platform integrity tag over critical QR fields.
  /// Uses a 32-bit bounded polynomial hash with unsigned operations that produce
  /// bit-for-bit identical hex output across 64-bit Dart VM (Android/iOS) and
  /// JavaScript float64/int32 (Flutter Web / Chrome).
  static String computeIntegrityTag({
    required String sessionId,
    required String qrToken,
    required String attendanceType,
    required DateTime expiresAt,
  }) {
    final epochSeconds = expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final canonical = '$sessionId|$qrToken|$attendanceType|$epochSeconds';
    int h1 = 5381;
    int h2 = 52711;
    for (final codeUnit in canonical.codeUnits) {
      h1 = (((h1 << 5) + h1) + codeUnit) & 0xFFFFFFFF;
      h2 = (((h2 << 5) - h2) ^ codeUnit) & 0xFFFFFFFF;
    }
    final s1 = (h1 >>> 0).toRadixString(16).padLeft(8, '0');
    final s2 = (h2 >>> 0).toRadixString(16).padLeft(8, '0');
    return '$s1$s2';
  }

  /// Backward-compatible legacy FNV tag verifier (epoch seconds).
  static String _computeLegacyFnvIntegrityTag({
    required String sessionId,
    required String qrToken,
    required String attendanceType,
    required DateTime expiresAt,
  }) {
    final epochSeconds = expiresAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final canonical = '$sessionId|$qrToken|$attendanceType|$epochSeconds';
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    for (final codeUnit in canonical.codeUnits) {
      h1 ^= codeUnit;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 << 5) ^ (h2 >> 3) ^ codeUnit) & 0xFFFFFFFF;
    }
    return '${(h1 >>> 0).toRadixString(16).padLeft(8, '0')}${(h2 >>> 0).toRadixString(16).padLeft(8, '0')}';
  }

  /// Backward-compatible legacy FNV tag verifier (ISO 8601 string).
  static String _computeLegacyIsoIntegrityTag({
    required String sessionId,
    required String qrToken,
    required String attendanceType,
    required DateTime expiresAt,
  }) {
    final canonical =
        '$sessionId|$qrToken|$attendanceType|${expiresAt.toUtc().toIso8601String()}';
    var h1 = 0x811c9dc5;
    var h2 = 0x9e3779b9;
    for (final codeUnit in canonical.codeUnits) {
      h1 ^= codeUnit;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 = ((h2 << 5) ^ (h2 >> 3) ^ codeUnit) & 0xFFFFFFFF;
    }
    return '${(h1 >>> 0).toRadixString(16).padLeft(8, '0')}${(h2 >>> 0).toRadixString(16).padLeft(8, '0')}';
  }

  QrPayload withIntegrityTag() {
    return QrPayload(
      sessionId: sessionId,
      qrToken: qrToken,
      attendanceType: attendanceType,
      expiresAt: expiresAt,
      issuedAt: issuedAt,
      generatedBy: generatedBy,
      signature: computeIntegrityTag(
        sessionId: sessionId,
        qrToken: qrToken,
        attendanceType: attendanceType,
        expiresAt: expiresAt,
      ),
    );
  }

  bool get hasValidIntegrityTag {
    if (signature == null || signature!.isEmpty) return false;
    final expectedNew = computeIntegrityTag(
      sessionId: sessionId,
      qrToken: qrToken,
      attendanceType: attendanceType,
      expiresAt: expiresAt,
    );
    if (signature == expectedNew) return true;

    final expectedFnv = _computeLegacyFnvIntegrityTag(
      sessionId: sessionId,
      qrToken: qrToken,
      attendanceType: attendanceType,
      expiresAt: expiresAt,
    );
    if (signature == expectedFnv) return true;

    final expectedIso = _computeLegacyIsoIntegrityTag(
      sessionId: sessionId,
      qrToken: qrToken,
      attendanceType: attendanceType,
      expiresAt: expiresAt,
    );
    return signature == expectedIso;
  }

  bool isExpiredAt([DateTime? reference]) {
    final now = (reference ?? DateTime.now()).toUtc();
    return now.isAfter(expiresAt.toUtc());
  }

  Duration remainingAt([DateTime? reference]) {
    final now = (reference ?? DateTime.now()).toUtc();
    return expiresAt.toUtc().difference(now);
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'qr_token': qrToken,
      'attendance_type': attendanceType,
      'expires_at': expiresAt.toUtc().toIso8601String(),
      if (issuedAt != null) 'issued_at': issuedAt!.toUtc().toIso8601String(),
      if (generatedBy != null) 'generated_by': generatedBy,
      if (signature != null) 'sig': signature,
    };
  }

  String toRawPayload() => jsonEncode(toJson());

  /// Parses and validates the structural integrity of a scanned QR string.
  static QrPayload? tryParse(String raw) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) {
      debugPrint('[QrPayload.tryParse] QR string is empty.');
      return null;
    }

    // Strip BOM or zero-width spaces that some scanner engines prepend.
    trimmed = trimmed.replaceAll('\uFEFF', '').replaceAll('\u200B', '').trim();

    // Handle surrounding single or double quotes
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      if (trimmed.length > 2) {
        trimmed = trimmed.substring(1, trimmed.length - 1).trim();
      }
    }

    // Handle escaped JSON strings (e.g. {\"session_id\":...})
    if (trimmed.contains(r'\"')) {
      trimmed = trimmed.replaceAll(r'\"', '"');
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        debugPrint('[QrPayload.tryParse] Decoded JSON is not a Map: $decoded');
        return null;
      }
      final map = decoded.map((k, v) => MapEntry(k.toString(), v));

      final sessionId =
          (map['session_id'] ?? map['sessionId'] ?? '').toString().trim();
      final qrToken =
          (map['qr_token'] ?? map['qrToken'] ?? map['token'] ?? '')
              .toString()
              .trim();

      final rawType =
          (map['attendance_type'] ?? map['attendanceType'] ?? map['type'] ?? '')
              .toString()
              .trim()
              .toLowerCase()
              .replaceAll('-', '_')
              .replaceAll(' ', '_');

      final attendanceType = switch (rawType) {
        'check_in' || 'checkin' || 'in' => AppConstants.typeCheckIn,
        'check_out' || 'checkout' || 'out' => AppConstants.typeCheckOut,
        _ => null,
      };

      if (sessionId.isEmpty || qrToken.length < 6 || attendanceType == null) {
        debugPrint(
          '[QrPayload.tryParse] Missing required fields: sessionId="$sessionId", '
          'qrTokenLength=${qrToken.length}, attendanceType="$attendanceType"',
        );
        return null;
      }

      final expiresRaw =
          (map['expires_at'] ?? map['expiresAt'] ?? map['expires'] ?? '')
              .toString()
              .trim();
      if (expiresRaw.isEmpty) {
        debugPrint('[QrPayload.tryParse] Missing expiration timestamp.');
        return null;
      }

      DateTime? expiresAt = DateTime.tryParse(expiresRaw);
      if (expiresAt == null) {
        final epoch = int.tryParse(expiresRaw);
        if (epoch != null) {
          expiresAt = epoch > 1000000000000
              ? DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true)
              : DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true);
        }
      }
      if (expiresAt == null) {
        debugPrint('[QrPayload.tryParse] Unparseable expires_at: "$expiresRaw"');
        return null;
      }

      final issuedRaw =
          (map['issued_at'] ?? map['issuedAt'] ?? map['issued'])
              ?.toString()
              .trim();
      DateTime? issuedAt;
      if (issuedRaw != null && issuedRaw.isNotEmpty) {
        issuedAt = DateTime.tryParse(issuedRaw);
        if (issuedAt == null) {
          final epoch = int.tryParse(issuedRaw);
          if (epoch != null) {
            issuedAt = epoch > 1000000000000
                ? DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true)
                : DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true);
          }
        }
      }

      if (issuedAt != null && expiresAt.toUtc().isBefore(issuedAt.toUtc())) {
        debugPrint(
          '[QrPayload.tryParse] expiresAt (${expiresAt.toIso8601String()}) '
          'is before issuedAt (${issuedAt.toIso8601String()})',
        );
        return null;
      }

      final signature =
          (map['sig'] ?? map['signature'] ?? map['hash'])?.toString().trim();

      final payload = QrPayload(
        sessionId: sessionId,
        qrToken: qrToken,
        attendanceType: attendanceType,
        expiresAt: expiresAt,
        issuedAt: issuedAt,
        generatedBy: (map['generated_by'] ?? map['generatedBy'])?.toString(),
        signature: signature,
      );

      // If an integrity tag is attached, reject any tampered payload immediately.
      if (signature != null &&
          signature.isNotEmpty &&
          !payload.hasValidIntegrityTag) {
        debugPrint(
          '[QrPayload.tryParse] Integrity signature verification failed: '
          'scanned="$signature", expected="${computeIntegrityTag(sessionId: sessionId, qrToken: qrToken, attendanceType: attendanceType, expiresAt: expiresAt)}"',
        );
        return null;
      }

      return payload;
    } catch (e, stack) {
      debugPrint('[QrPayload.tryParse] Unexpected parsing error: $e\n$stack');
      return null;
    }
  }

  @override
  List<Object?> get props => [
        sessionId,
        qrToken,
        attendanceType,
        expiresAt,
        issuedAt,
        generatedBy,
        signature,
      ];
}

