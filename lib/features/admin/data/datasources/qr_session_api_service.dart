import 'package:newwone/core/config/api_config.dart';
import 'package:newwone/core/network/dio_client.dart';
import 'package:newwone/features/qr_scanner/domain/entities/qr_payload.dart';

/// REST API service for dynamic QR session generation.
class QrSessionApiService {
  const QrSessionApiService(this._client);

  final DioClient _client;

  /// `POST /admin/qr-session`
  Future<Map<String, dynamic>> createQrSession(QrPayload payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiConfig.adminQrSessionEndpoint,
      data: payload.toJson(),
    );
    return response.data ?? <String, dynamic>{};
  }
}

