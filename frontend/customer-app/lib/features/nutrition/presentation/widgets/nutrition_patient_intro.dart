import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionPatientIntro extends StatelessWidget {
  const NutritionPatientIntro({
    super.key,
    this.name,
    required this.editing,
  });

  final String? name;
  final bool editing;

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
              editing ? 'Hồ sơ dinh dưỡng' : 'Thực đơn cá nhân hóa',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            editing
                ? name == null
                    ? 'Cập nhật thông tin'
                    : 'Cập nhật thông tin cho $name'
                : name == null
                    ? 'Thực đơn đang chọn'
                    : 'Thực đơn cho $name',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            editing
                ? 'Kiểm tra và lưu những thay đổi về sức khỏe hoặc nhu cầu ăn uống.'
                : 'Các món được gợi ý theo thông tin đã lưu. Cập nhật hồ sơ khi tình trạng sức khỏe thay đổi.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
        ],
      );
}
