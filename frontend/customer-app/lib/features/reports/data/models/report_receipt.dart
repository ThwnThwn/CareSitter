class ReportReceipt {
  const ReportReceipt(
      {required this.id,
      required this.bookingId,
      required this.status,
      required this.sizeBytes,
      required this.createdAt});
  factory ReportReceipt.fromJson(Map<String, dynamic> json) => ReportReceipt(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      status: json['status'] as String,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String));
  final String id, bookingId, status;
  final int sizeBytes;
  final DateTime createdAt;
  bool get completed => status == 'COMPLETED';
}
