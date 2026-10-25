/// Model ánh xạ response từ GET /api/v1/services
class ServiceModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final int defaultDurationMinutes;
  final int baseHourlyPrice;
  final double platformFeePercent;

  const ServiceModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.defaultDurationMinutes,
    this.baseHourlyPrice = 0,
    this.platformFeePercent = 0,
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

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: (json['id'] ?? json['Id'])?.toString() ?? '',
        code: (json['code'] ?? json['Code']) as String? ?? '',
        name: (json['name'] ?? json['Name']) as String? ?? 'Dịch vụ',
        description:
            json['description'] as String? ?? json['Description'] as String?,
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
      );
}
