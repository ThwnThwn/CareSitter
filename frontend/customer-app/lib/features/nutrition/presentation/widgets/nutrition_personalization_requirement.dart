import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../domain/nutrition_personalization_rules.dart';

class NutritionPersonalizationRequirement extends StatelessWidget {
  const NutritionPersonalizationRequirement(
      {super.key, required this.readiness});

  final NutritionPersonalizationReadiness readiness;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: readiness.isReady
            ? 'Đã hoàn tất thông tin bắt buộc cho gợi ý thực đơn'
            : 'Cần hoàn tất thông tin bắt buộc cho gợi ý thực đơn',
        child: Card(
          color: readiness.isReady
              ? AppColors.successLight
              : AppColors.warningLight,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  readiness.isReady
                      ? Icons.verified_outlined
                      : Icons.info_outline,
                  color:
                      readiness.isReady ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        readiness.isReady
                            ? 'Đã sẵn sàng kiểm tra thông tin'
                            : 'Hoàn tất thông tin bắt buộc',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Thông tin đã xác nhận được dùng để đối chiếu món ăn phù hợp. '
                        'Ứng dụng không chẩn đoán bệnh.',
                      ),
                      if (!readiness.isReady) ...[
                        const SizedBox(height: AppSpacing.sm),
                        for (final field in readiness.missingFields)
                          Text('• $field'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
