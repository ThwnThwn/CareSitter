class RefundRecord {
  const RefundRecord({
    required this.id,
    required this.bookingId,
    required this.provider,
    required this.amount,
    required this.currency,
    required this.reason,
    required this.status,
    required this.requestedAt,
    this.completedAt,
  });

  final String id;
  final String bookingId;
  final String provider;
  final int amount;
  final String currency;
  final String reason;
  final String status;
  final DateTime requestedAt;
  final DateTime? completedAt;

  bool get needsSupport => status == 'MANUAL_REQUIRED' || status == 'FAILED';

  factory RefundRecord.fromJson(Map<String, dynamic> json) => RefundRecord(
        id: json['id']?.toString() ?? '',
        bookingId: json['bookingId']?.toString() ?? '',
        provider: json['provider']?.toString().toUpperCase() ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        currency: json['currency']?.toString() ?? 'VND',
        reason: json['reason']?.toString() ?? '',
        status: json['status']?.toString().toUpperCase() ?? 'PENDING',
        requestedAt: DateTime.tryParse(json['requestedAt']?.toString() ?? '')
                ?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        completedAt:
            DateTime.tryParse(json['completedAt']?.toString() ?? '')?.toLocal(),
      );
}
