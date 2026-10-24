import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_checklist_item_model.dart';
import 'package:caresitter_customer/features/catalog/data/models/service_model.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => ServiceRepository(ref.read(dioClientProvider)),
);

class ServiceRepository {
  final DioClient _dio;

  const ServiceRepository(this._dio);

  Future<List<ServiceModel>> getServices() async {
    final response = await _dio.get<List<dynamic>>(ApiPaths.services);
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ServiceModel.fromJson)
        .toList();
  }

  Future<List<ServiceChecklistItemModel>> getServiceChecklist(
    String serviceId,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      '${ApiPaths.services}/$serviceId/checklist-templates',
    );
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ServiceChecklistItemModel.fromJson)
        .toList(growable: false);
  }
}
