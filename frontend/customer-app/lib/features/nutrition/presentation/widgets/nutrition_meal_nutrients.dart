import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../models/nutrition_meal_detail_format.dart';

class NutritionMealNutrients extends StatelessWidget {
  const NutritionMealNutrients({super.key, required this.nutrients});
  final Map<String, dynamic>? nutrients;
  static const _fields = [
    ('energy_kcal', 'Năng lượng', 'kcal'),
    ('protein_g', 'Đạm', 'g'),
    ('carbohydrate_g', 'Carbohydrate', 'g'),
    ('fat_g', 'Chất béo', 'g'),
    ('fiber_g', 'Chất xơ', 'g'),
    ('sodium_mg', 'Natri', 'mg'),
    ('potassium_mg', 'Kali', 'mg'),
    ('phosphorus_mg', 'Phospho', 'mg'),
    ('fluid_ml', 'Dịch', 'ml'),
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dinh dưỡng mỗi phần',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(builder: (context, constraints) {
            final columns = constraints.maxWidth >= 280 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.3
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                    columns;
            return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (key, label, unit) in _fields)
                    SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.control),
                          decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm)),
                          child: Text(
                              '$label: ${nutrients?[key] is num ? '${nutritionDisplayValue(nutrients![key])} $unit' : 'Chưa có dữ liệu'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: key == 'protein_g'
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.w500)),
                        )),
                ]);
          }),
        ],
      );
}
