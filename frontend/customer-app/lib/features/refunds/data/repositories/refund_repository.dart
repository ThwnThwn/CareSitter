import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/refunds/data/models/refund_record.dart';

final refundRepositoryProvider = Provider<RefundRepository>(
  (ref) => RefundRepository(ref.read(dioClientProvider)),
);

class RefundRepository {
  const RefundRepository(this._dio);

  final DioClient _dio;

  Future<List<RefundRecord>> getMyRefunds({
    int pageSize = 50,
    ApiCancellation? cancellation,
  }) async {
    final query = {'page': 1, 'pageSize': pageSize};
    final response = cancellation == null
        ? await _dio.get<Map<String, dynamic>>(ApiPaths.refunds, query: query)
        : await _dio.getCancelable<Map<String, dynamic>>(
            ApiPaths.refunds,
            query: query,
            cancelToken: cancellation.transportToken,
          );
    return (response.data?['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RefundRecord.fromJson)
        .toList(growable: false);
  }
}
