import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/dio_client.dart';

class CustomerWallet {
  final int availableBalance;
  final int pendingBalance;
  final String currency;
  final List<WalletTransaction> transactions;

  const CustomerWallet({
    required this.availableBalance,
    required this.pendingBalance,
    required this.currency,
    required this.transactions,
  });
}

class WalletTransaction {
  final String id;
  final String? bookingId;
  final String type;
  final int amount;
  final String currency;
  final String status;
  final String direction;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.bookingId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.direction,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id']?.toString() ?? '',
      bookingId: json['bookingId']?.toString(),
      type: json['transactionType']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'VND',
      status: json['status']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

final customerWalletProvider =
    AsyncNotifierProvider<CustomerWalletStore, CustomerWallet>(
  CustomerWalletStore.new,
);

class CustomerWalletStore extends AsyncNotifier<CustomerWallet> {
  @override
  Future<CustomerWallet> build() => _fetch();

  Future<CustomerWallet> _fetch() async {
    final dio = ref.read(dioClientProvider);
    final responses = await Future.wait([
      dio.get<Map<String, dynamic>>('/wallet'),
      dio.get<Map<String, dynamic>>('/wallet/transactions'),
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

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
