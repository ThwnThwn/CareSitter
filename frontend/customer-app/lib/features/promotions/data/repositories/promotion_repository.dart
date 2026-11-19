import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/promotion_model.dart';
import '../models/promotion_quote_model.dart';

final promotionRepositoryProvider = Provider<PromotionRepository>(
  (ref) => PromotionRepository(ref.read(dioClientProvider)),
);

class PromotionRepository {
  const PromotionRepository(this._client);

  final DioClient _client;

  Future<List<PromotionModel>> listActive(ApiCancellation cancellation) async {
    final response = await _client.getCancelable<List<dynamic>>(
      ApiPaths.promotions,
      cancelToken: cancellation.transportToken,
    );
    return response.data!
        .map((item) => PromotionModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<PromotionQuoteModel> preview(
    String code,
    PromotionBookingSlot slot,
    ApiCancellation cancellation,
  ) async {
    final response = await _client.postCancelable<Map<String, dynamic>>(
      '${ApiPaths.promotions}/preview',
      data: {
        'code': code,
        'serviceTypeId': slot.serviceTypeId,
        'scheduledStart': slot.start.toUtc().toIso8601String(),
        'scheduledEnd': slot.end.toUtc().toIso8601String(),
      },
      cancelToken: cancellation.transportToken,
    );
    final quote = PromotionQuoteModel.fromJson(response.data ?? {});
    if (quote.code != code) {
      throw const FormatException('Mã ưu đãi không khớp.');
    }
    return quote;
  }
}
