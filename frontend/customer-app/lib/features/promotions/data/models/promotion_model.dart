class PromotionModel {
  const PromotionModel({
    required this.id,
    required this.code,
    required this.title,
    required this.summary,
    required this.badgeText,
    required this.endsAt,
    this.description,
    this.minOrderAmount = 0,
    this.maxDiscountAmount,
    this.perCustomerUsageLimit,
    this.eligibleServiceIds = const [],
    this.terms = const [],
    this.firstPaidBookingOnly = false,
  });

  final String id, code, title, summary, badgeText;
  final DateTime endsAt;
  final bool firstPaidBookingOnly;
  final String? description;
  final int minOrderAmount;
  final int? maxDiscountAmount, perCustomerUsageLimit;
  final List<String> eligibleServiceIds, terms;

  factory PromotionModel.fromJson(Map<String, dynamic> json) => PromotionModel(
        id: json['id'] as String,
        code: json['code'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        badgeText: json['badgeText'] as String,
        endsAt: DateTime.parse(json['endsAt'] as String).toLocal(),
        description: json['description'] as String?,
        minOrderAmount: (json['minOrderAmount'] as num?)?.toInt() ?? 0,
        maxDiscountAmount: (json['maxDiscountAmount'] as num?)?.toInt(),
        perCustomerUsageLimit: (json['perCustomerUsageLimit'] as num?)?.toInt(),
        terms: List<String>.from(json['terms'] as List? ?? const []),
        eligibleServiceIds:
            List<String>.from(json['eligibleServiceIds'] as List? ?? const []),
        firstPaidBookingOnly: json['firstPaidBookingOnly'] as bool? ?? false,
      );
}
