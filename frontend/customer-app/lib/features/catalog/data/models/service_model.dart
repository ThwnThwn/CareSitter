class ServicePlanModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String billingUnit;
  final int durationMinutes;
  final int includedSessions;
  final int totalPrice;
  final int? validityDays;
  final bool isActive;

  const ServicePlanModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.billingUnit,
    required this.durationMinutes,
    required this.includedSessions,
    required this.totalPrice,
    this.validityDays,
    this.isActive = true,
  });

  bool get isSessionPackage => billingUnit == 'SESSION_PACKAGE';

  factory ServicePlanModel.fromJson(Map<String, dynamic> json) =>
      ServicePlanModel(
        id: (json['id'] ?? json['Id'])?.toString() ?? '',
        code: (json['code'] ?? json['Code']) as String? ?? '',
        name: (json['name'] ?? json['Name']) as String? ?? 'Phương án',
        description:
            json['description'] as String? ?? json['Description'] as String?,
        billingUnit: (json['billingUnit'] ?? json['BillingUnit']) as String? ??
            'SESSION',
        durationMinutes:
            (json['durationMinutes'] as num? ?? json['DurationMinutes'] as num?)
                    ?.toInt() ??
                60,
        includedSessions: (json['includedSessions'] as num? ??
                    json['IncludedSessions'] as num?)
                ?.toInt() ??
            1,
        totalPrice: (json['totalPrice'] as num? ?? json['TotalPrice'] as num?)
                ?.toInt() ??
            0,
        validityDays:
            (json['validityDays'] as num? ?? json['ValidityDays'] as num?)
                ?.toInt(),
        isActive:
            json['isActive'] as bool? ?? json['IsActive'] as bool? ?? true,
      );
}

/// Model ánh xạ response từ GET /api/v1/services
class ServiceModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String? imageUrl;
  final int defaultDurationMinutes;
  final int baseHourlyPrice;
  final double platformFeePercent;
  final List<ServicePlanModel> plans;

  const ServiceModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.imageUrl,
    required this.defaultDurationMinutes,
    this.baseHourlyPrice = 0,
    this.platformFeePercent = 0,
    this.plans = const [],
  });

  /// Icon tương ứng với code gói
  String get icon {
    if (code.contains('NONMED_ESSENTIAL')) return '🧺';
    if (code.contains('NONMED_COMPANION')) return '🤝';
    if (code.contains('NONMED_DAY')) return '☀️';
    if (code.contains('NONMED_NIGHT')) return '🌙';
    if (code.contains('DUONG')) return '🌱';
    if (code.contains('AN')) return '🌿';
    if (code.contains('TAM')) return '🌸';
    if (code.contains('PHUCHOI')) return '🍀';
    if (code.contains('DONGHANH')) return '🌻';
    if (code.contains('DEM')) return '🌙';
    return '🫶';
  }

  String get category => 'Chăm sóc phi y tế';

  double get pricePerHour {
    return baseHourlyPrice.toDouble();
  }

  List<ServicePlanModel> get activePlans =>
      plans.where((plan) => plan.isActive).toList(growable: false);

  int get minimumPlanPrice {
    final prices = activePlans
        .where((plan) => plan.totalPrice > 0)
        .map((plan) => plan.totalPrice)
        .toList(growable: false);
    if (prices.isEmpty) return 0;
    return prices.reduce((left, right) => left < right ? left : right);
  }

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: (json['id'] ?? json['Id'])?.toString() ?? '',
        code: (json['code'] ?? json['Code']) as String? ?? '',
        name: (json['name'] ?? json['Name']) as String? ?? 'Dịch vụ',
        description:
            json['description'] as String? ?? json['Description'] as String?,
        imageUrl: (json['imageUrl'] ?? json['ImageUrl']) as String?,
        defaultDurationMinutes: json['defaultDurationMinutes'] as int? ??
            json['DefaultDurationMinutes'] as int? ??
            60,
        baseHourlyPrice:
            (json['baseHourlyPrice'] as num? ?? json['BaseHourlyPrice'] as num?)
                    ?.toInt() ??
                0,
        platformFeePercent: (json['platformFeePercent'] as num? ??
                    json['PlatformFeePercent'] as num?)
                ?.toDouble() ??
            0,
        plans: ((json['plans'] ?? json['Plans']) as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ServicePlanModel.fromJson)
            .toList(growable: false),
      );
}
