import '../../data/models/nutrition_decision_model.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionFactAlerts extends StatelessWidget {
  const NutritionFactAlerts({
    super.key,
    required this.decision,
    required this.state,
    this.health,
  });

  final NutritionDecisionModel decision;
  final String state;
  final Map<String, dynamic>? health;

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    if (state == 'needs_information') {
      final allergies = health?['allergies'];
      if (allergies is List) {
        for (final field in decision.missingFields) {
          final match = RegExp(r'^allergies/(\d+)$').firstMatch(field);
          final index = match == null ? null : int.tryParse(match.group(1)!);
          if (index == null || index >= allergies.length) continue;
          final item = allergies[index];
          final label = item is String
              ? item
              : item is Map
                  ? (item['label'] ?? item['code'])?.toString()
                  : null;
          if (label == null || label.trim().isEmpty) continue;
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
                'Chưa nhận diện được dị ứng “$label”. Thông tin vẫn được lưu; chưa thể gợi ý thực đơn cho đến khi mục này được hỗ trợ.',
                style: const TextStyle(color: AppColors.error)),
          ));
        }
      }
    }
    if (state == 'needs_professional_guidance') {
      for (final field in decision.requiredGuidance) {
        final label = switch (field) {
          'swallowingStatus' => 'Khả năng nuốt',
          'feedingRoute' => 'Cách ăn uống hiện tại',
          'fluidRestriction' => 'Hướng dẫn hạn chế nước',
          'electrolyteRestriction' => 'Hướng dẫn về điện giải',
          'medications' => 'Thuốc đang dùng',
          'under_18' => 'Độ tuổi của người được chăm sóc',
          _ => null,
        };
        if (label != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text('Cần lưu ý: $label',
                style: const TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ));
        }
      }
      widgets.add(const Text(
          'Hồ sơ cần thêm hướng dẫn chuyên biệt hoặc đang ngoài phạm vi nội dung được hỗ trợ. Không tự đổi sang ăn mềm hay đặt giới hạn dinh dưỡng.'));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}
