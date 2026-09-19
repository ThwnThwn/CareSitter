import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:caregiver_app/core/api/api_constants.dart';
import 'package:caregiver_app/core/api/dio_client.dart';

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  return EarningsRepository(ref.read(dioClientProvider));
});

class EarningsRepository {
  final DioClient _dio;

  const EarningsRepository(this._dio);

  Future<double> getAvailableBalance() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiPaths.wallet);
    final data = response.data ?? const <String, dynamic>{};
    return _number(data['availableBalance'] ?? data['AvailableBalance']);
  }

  Future<void> requestWithdrawal({
    required double amount,
    required String bankName,
    required String accountHolderName,
    required String accountNumber,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/payments/payouts',
      data: {
        'amount': amount.round(),
        'bankName': bankName,
        'accountHolderName': accountHolderName,
        'accountNumber': accountNumber,
        'idempotencyKey': const Uuid().v4(),
      },
    );
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
