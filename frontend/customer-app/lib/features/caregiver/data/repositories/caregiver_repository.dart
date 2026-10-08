import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

final caregiverRepositoryProvider = Provider<CaregiverRepository>(
  (ref) => CaregiverRepository(ref.read(dioClientProvider)),
);

class CaregiverRepository {
  final DioClient _dio;

  const CaregiverRepository(this._dio);

  Future<List<CaregiverModel>> getCaregivers({
    double? latitude,
    double? longitude,
    String? city,
    String? district,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (latitude != null || longitude != null) {
      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        throw ArgumentError('Tọa độ tìm chăm sóc viên không hợp lệ.');
      }
    }
    final response = await _dio.get<Map<String, dynamic>>(
      ApiPaths.caregivers,
      query: {
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lng': longitude,
        if (city != null) 'city': city,
        if (district != null) 'district': district,
        'page': page,
        'pageSize': pageSize,
      },
    );
    final items = response.data?['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CaregiverModel.fromJson)
        .toList();
  }

  Future<CaregiverModel?> getCaregiver(String id) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>(ApiPaths.caregiver(id));
      final data = response.data;
      return data == null ? null : CaregiverModel.fromJson(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
