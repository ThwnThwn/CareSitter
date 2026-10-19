import 'nutrition_personalization_readiness.dart';

export 'nutrition_personalization_readiness.dart';

/// Keeps the client-side entry gate aligned with the server's Nutrition policy.
/// The server remains authoritative because a profile can be changed elsewhere.
class NutritionPersonalizationRules {
  const NutritionPersonalizationRules._();

  static NutritionPersonalizationReadiness evaluate({
    required String allergyStatus,
    required Object? allergies,
    required String conditionStatus,
    required Object? chronicConditions,
    required String medicationsStatus,
    required Object? medications,
    required String feedingRoute,
    required String swallowingStatus,
    required String fluidRestriction,
    required String electrolyteRestriction,
  }) {
    final issues = <String>[];
    if (!{'reported_none', 'reported_present'}.contains(allergyStatus)) {
      issues.add('Xác nhận dị ứng thực phẩm');
    } else if (allergyStatus == 'reported_present' && !_hasEntries(allergies)) {
      issues.add('Ghi rõ thực phẩm gây dị ứng');
    } else if (allergyStatus == 'reported_none' && _hasEntries(allergies)) {
      issues.add('Làm rõ thông tin dị ứng mâu thuẫn');
    }

    if (!{'reported_none', 'reported_present'}.contains(conditionStatus)) {
      issues.add('Xác nhận tình trạng bệnh lý');
    } else if (conditionStatus == 'reported_present' &&
        !_hasEntries(chronicConditions)) {
      issues.add('Ghi rõ bệnh lý đã biết');
    } else if (conditionStatus == 'reported_none' &&
        _hasEntries(chronicConditions)) {
      issues.add('Làm rõ thông tin bệnh lý mâu thuẫn');
    }

    if (!{'reported_none', 'reported_present'}.contains(medicationsStatus)) {
      issues.add('Xác nhận việc dùng thuốc hiện tại');
    } else if (medicationsStatus == 'reported_present' &&
        !_hasEntries(medications)) {
      issues.add('Ghi rõ thuốc đang dùng');
    } else if (medicationsStatus == 'reported_none' &&
        _hasEntries(medications)) {
      issues.add('Làm rõ thông tin thuốc mâu thuẫn');
    }

    _requireKnown(issues, feedingRoute, 'Xác nhận cách ăn uống');
    _requireKnown(issues, swallowingStatus, 'Xác nhận khả năng nuốt');
    _requireKnown(issues, fluidRestriction, 'Xác nhận hạn chế nước');
    _requireKnown(
        issues, electrolyteRestriction, 'Xác nhận hướng dẫn điện giải');

    return NutritionPersonalizationReadiness(
      List.unmodifiable(issues.take(3)),
      totalIssueCount: issues.length,
    );
  }

  static void _requireKnown(List<String> issues, String value, String label) {
    if (value.trim().isEmpty || value == 'unknown') issues.add(label);
  }

  static bool _hasEntries(Object? raw) {
    if (raw is! Iterable) return false;
    return raw.any((item) {
      if (item is String) return item.trim().isNotEmpty;
      if (item is Map) {
        final label = item['label'] ?? item['code'] ?? item['name'];
        return label is String && label.trim().isNotEmpty;
      }
      return false;
    });
  }
}
