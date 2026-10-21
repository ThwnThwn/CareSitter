import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionPatientIntro extends StatelessWidget {
  const NutritionPatientIntro({super.key, this.name});

  final String? name;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'Hồ sơ dinh dưỡng',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name == null ? 'Hồ sơ đang chọn' : 'Thực đơn cho $name',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Kiểm tra thông tin sức khỏe trước khi xem gợi ý. '
            'Thông tin do bạn và gia đình cung cấp.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
        ],
      );
}
