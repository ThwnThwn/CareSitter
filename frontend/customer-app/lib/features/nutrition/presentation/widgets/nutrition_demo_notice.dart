import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionDemoNotice extends StatelessWidget {
  const NutritionDemoNotice({super.key, required this.graphUsed});
  final bool graphUsed;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              graphUsed ? 'DEMO · GraphRAG' : 'DEMO',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chưa kiểm duyệt lâm sàng. Nội dung chỉ dùng tham khảo trong bản demo.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      );
}
