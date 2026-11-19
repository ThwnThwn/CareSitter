enum WalletActivityKind { transactions, payouts }

typedef WalletActivityPage = ({List<WalletActivity> items, bool hasMore});

class WalletActivity {
  const WalletActivity({
    required this.kind,
    required this.amount,
    required this.status,
    required this.date,
    required this.isCredit,
    this.bankName,
  });

  factory WalletActivity.fromTransaction(Map<String, dynamic> json) =>
      WalletActivity(
        kind: json['transactionType'] as String,
        amount: (json['amount'] as num).toInt(),
        status: json['status'] as String,
        date: DateTime.parse(json['createdAt'] as String).toLocal(),
        isCredit: json['direction'] == 'CREDIT',
      );

  factory WalletActivity.fromPayout(Map<String, dynamic> json) =>
      WalletActivity(
        kind: 'PAYOUT_REQUEST',
        amount: (json['amount'] as num).toInt(),
        status: json['status'] as String,
        date: DateTime.parse(json['requestedAt'] as String).toLocal(),
        isCredit: false,
        bankName: json['bankName'] as String?,
      );

  final String kind;
  final int amount;
  final String status;
  final DateTime date;
  final bool isCredit;
  final String? bankName;
}
