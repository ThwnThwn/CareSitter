import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/api/api_constants.dart';
import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import '../models/wallet_activity.dart';

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  return EarningsRepository(ref.read(dioClientProvider));
});

class EarningsRepository {
  static const _payoutsPath = '/payments/payouts';
  final DioClient _dio;

  const EarningsRepository(this._dio);

  Future<double> getAvailableBalance() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiPaths.wallet);
    final data = response.data ?? const <String, dynamic>{};
    return _number(data['availableBalance'] ?? data['AvailableBalance']);
  }

  Future<WalletActivityPage> loadActivity(
    WalletActivityKind kind,
    int page, {
    ApiCancellation? token,
  }) async {
    const pageSize = 20;
    final payouts = kind == WalletActivityKind.payouts;
    final response = await _dio.get<Map<String, dynamic>>(
      payouts ? _payoutsPath : '${ApiPaths.wallet}/transactions',
      query: {'page': page, 'pageSize': pageSize},
      cancelToken: token?.transportToken,
    );
    final body = response.data;
    if (body == null || body['items'] is! List || body['total'] is! num) {
      throw const AppApiException(message: 'Máy chủ chưa trả về lịch sử ví.');
    }
    final parse =
        payouts ? WalletActivity.fromPayout : WalletActivity.fromTransaction;
    return (
      items: (body['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(parse)
          .toList(growable: false),
      hasMore: page * pageSize < (body['total'] as num),
    );
  }

  Future<void> requestWithdrawal({
    required double amount,
    required String bankName,
    required String bankBin,
    required String accountHolderName,
    required String accountNumber,
    required String idempotencyKey,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      _payoutsPath,
      data: {
        'amount': amount.round(),
        'bankName': bankName,
        'bankBin': bankBin,
        'accountHolderName': accountHolderName,
        'accountNumber': accountNumber,
        'idempotencyKey': idempotencyKey,
      },
    );
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
