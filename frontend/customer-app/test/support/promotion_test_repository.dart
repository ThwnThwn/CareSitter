import 'dart:async';

import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/features/promotions/data/models/promotion_model.dart';
import 'package:caresitter_customer/features/promotions/data/models/promotion_quote_model.dart';
import 'package:caresitter_customer/features/promotions/data/repositories/promotion_repository.dart';

const care20Quote = PromotionQuoteModel(
  code: 'CARE20',
  grossAmount: 150000,
  discountAmount: 30000,
  customerPayableAmount: 120000,
);

class PromotionTestRepository implements PromotionRepository {
  final requests = <({
    String code,
    PromotionBookingSlot slot,
    ApiCancellation cancellation,
    Completer<PromotionQuoteModel> response,
  })>[];

  @override
  Future<List<PromotionModel>> listActive(ApiCancellation cancellation) async =>
      [];

  @override
  Future<PromotionQuoteModel> preview(
      String code, PromotionBookingSlot slot, ApiCancellation cancellation) {
    final response = Completer<PromotionQuoteModel>();
    requests.add((
      code: code,
      slot: slot,
      cancellation: cancellation,
      response: response
    ));
    return response.future;
  }
}
