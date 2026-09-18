import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    String? city,
    String? district,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiPaths.caregivers,
      query: {
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
}
