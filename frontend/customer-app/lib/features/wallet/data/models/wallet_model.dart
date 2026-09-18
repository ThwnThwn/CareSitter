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
