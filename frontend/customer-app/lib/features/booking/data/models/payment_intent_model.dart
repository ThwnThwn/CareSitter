/// URL và trạng thái được backend xác nhận, không suy ra từ callback trình duyệt.
class PaymentIntentModel {
  final String id;
  final String status;
  final String paymentUrl;

  const PaymentIntentModel({
    required this.id,
    required this.status,
    required this.paymentUrl,
  });

  /// Parse response payment intent từ backend.
  factory PaymentIntentModel.fromJson(Map<String, dynamic> json) {
    return PaymentIntentModel(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentUrl: json['paymentUrl']?.toString() ?? '',
    );
  }
}
