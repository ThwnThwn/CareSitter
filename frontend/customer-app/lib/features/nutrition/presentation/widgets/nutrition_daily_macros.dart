import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../data/models/nutrition_meal_model.dart';
import '../models/nutrition_meal_detail_format.dart';
import '../models/nutrition_macro_calculation.dart';
import 'nutrition_macro_formula.dart';

class NutritionDailyMacros extends StatelessWidget {
  const NutritionDailyMacros({super.key, required this.meals});
  final List<NutritionMealModel> meals;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 340 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.3
              ? 3
              : 1;
          final width =
              (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dinh dưỡng trong ngày · ước tính',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final (key, label, background, foreground) in const [
                        (
                          'protein_g',
                          'Chất đạm',
                          AppColors.softOrange,
                          AppColors.brownOrange
                        ),
                        (
                          'carbohydrate_g',
                          'Đường bột',
                          AppColors.softBlue,
                          AppColors.blueDark
                        ),
                        (
                          'fat_g',
                          'Chất béo',
                          AppColors.pinkLight,
                          AppColors.pinkDark
                        ),
                      ])
                        SizedBox(
                            width: width,
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.compact),
                              decoration: BoxDecoration(
                                  color: background,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.compact)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(color: foreground)),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(_value(key),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                                color: foreground,
                                                fontWeight: FontWeight.w700)),
                                  ]),
                            )),
                    ]),
                NutritionMacroFormula(meals: meals),
              ]);
        }),
      );

  String _value(String key) {
    final sum = NutritionMacroCalculation(key, meals).total;
    if (sum == null) {
      return 'Chưa đủ dữ liệu';
    }
    return '${nutritionDisplayNumber(sum)} g';
  }
}
