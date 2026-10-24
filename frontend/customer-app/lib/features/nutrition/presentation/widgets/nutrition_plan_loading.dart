import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionPlanLoading extends StatelessWidget {
  const NutritionPlanLoading({super.key, this.name});

  final String? name;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.section),
        children: [
          Text(
            name == null ? 'Đang mở thực đơn' : 'Đang mở thực đơn cho $name',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'CareSitter đang tải thực đơn đã lưu gần nhất.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          const LinearProgressIndicator(
            semanticsLabel: 'Đang tải thực đơn đã lưu',
          ),
        ],
      );
}
