typedef PromotionBookingSlot = ({
  String serviceTypeId,
  DateTime start,
  DateTime end,
});

class PromotionQuoteModel {
  const PromotionQuoteModel({
    required this.code,
    required this.grossAmount,
    required this.discountAmount,
    required this.customerPayableAmount,
  });

  final String code;
  final int grossAmount, discountAmount, customerPayableAmount;

  factory PromotionQuoteModel.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final gross = json['grossAmount'];
    final discount = json['discountAmount'];
    final payable = json['customerPayableAmount'];
    if (code is! String ||
        code.isEmpty ||
        gross is! int ||
        discount is! int ||
        payable is! int ||
        discount < 0 ||
        payable <= 0 ||
        gross - discount != payable) {
      throw const FormatException('Thông tin ưu đãi không hợp lệ.');
    }
    return PromotionQuoteModel(
      code: code,
      grossAmount: gross,
      discountAmount: discount,
      customerPayableAmount: payable,
    );
  }
}
