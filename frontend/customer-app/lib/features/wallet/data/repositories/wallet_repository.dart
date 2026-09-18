import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/wallet/data/models/wallet_model.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(ref.read(dioClientProvider)),
);

class WalletRepository {
  final DioClient _dio;

  const WalletRepository(this._dio);

  Future<CustomerWallet> getWallet() async {
    final responses = await Future.wait([
      _dio.get<Map<String, dynamic>>('/wallet'),
      _dio.get<Map<String, dynamic>>('/wallet/transactions'),
    ]);
    final wallet = responses[0].data ?? const <String, dynamic>{};
    final transactionResponse = responses[1].data ?? const <String, dynamic>{};
    final rawItems = transactionResponse['items'] as List<dynamic>? ?? const [];

    return CustomerWallet(
      availableBalance: (wallet['availableBalance'] as num?)?.toInt() ?? 0,
      pendingBalance: (wallet['pendingBalance'] as num?)?.toInt() ?? 0,
      currency: wallet['currency']?.toString() ?? 'VND',
      transactions: rawItems
          .whereType<Map<String, dynamic>>()
          .map(WalletTransaction.fromJson)
          .toList(),
    );
  }
}
