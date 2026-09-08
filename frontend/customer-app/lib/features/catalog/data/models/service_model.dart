/// Model ánh xạ response từ GET /api/v1/services
class ServiceModel {
  final String id;
  final String code;
  final String name;
  final String? description;
  final int defaultDurationMinutes;

  const ServiceModel({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.defaultDurationMinutes,
  });

  /// Icon tương ứng với code gói
  String get icon {
    if (code.contains('DUONG')) return '🌱';
    if (code.contains('AN')) return '🌿';
    if (code.contains('TAM')) return '🌸';
    return '🏥';
  }

  String get category => 'Gói Genki';

  double get pricePerHour {
    if (code.contains('DUONG')) return 100000.0;
    if (code.contains('AN')) return 120000.0;
    if (code.contains('TAM')) return 150000.0;
    return 120000.0;
  }

  factory ServiceModel.fromJson(Map<String, dynamic> json) => ServiceModel(
        id: (json['id'] ?? json['Id'])?.toString() ?? '',
        code: (json['code'] ?? json['Code']) as String? ?? '',
        name: (json['name'] ?? json['Name']) as String? ?? 'Dịch vụ',
        description: json['description'] as String? ?? json['Description'] as String?,
        defaultDurationMinutes:
            json['defaultDurationMinutes'] as int? ?? json['DefaultDurationMinutes'] as int? ?? 60,
      );
}
