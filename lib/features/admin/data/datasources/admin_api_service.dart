import 'package:newwone/core/config/api_config.dart';
import 'package:newwone/core/network/dio_client.dart';
import 'package:newwone/features/auth/data/models/user_model.dart';

/// REST API service for Admin employee directory endpoints.
class AdminApiService {
  const AdminApiService(this._client);

  final DioClient _client;

  /// `GET /admin/employees`
  Future<List<UserModel>> getEmployees({String? dateKey}) async {
    final response = await _client.get<dynamic>(
      ApiConfig.adminEmployeesEndpoint,
      queryParameters: dateKey != null ? {'date': dateKey} : null,
    );
    final body = response.data;
    if (body == null) return [];
    if (body is List) {
      return body
          .whereType<Map<String, dynamic>>()
          .map(UserModel.fromJson)
          .toList();
    }
    if (body is Map<String, dynamic>) {
      final list = body['employees'] ?? body['data'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(UserModel.fromJson)
            .toList();
      }
    }
    return [];
  }
}

