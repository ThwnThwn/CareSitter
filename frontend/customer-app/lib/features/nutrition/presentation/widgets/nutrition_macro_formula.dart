import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../data/models/nutrition_meal_model.dart';
import '../models/nutrition_macro_calculation.dart';

class NutritionMacroFormula extends StatelessWidget {
  const NutritionMacroFormula({super.key, required this.meals});
  final List<NutritionMealModel> meals;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Cách tính',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.primary)),
          childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Tổng trong ngày = cộng dưỡng chất của các món trong thực đơn này.'),
            Text(
                'Ô tổng làm tròn đến 0,1 g; phép cộng bên dưới giữ đến 0,01 g.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            for (final field in NutritionMacroCalculation.fields.entries)
              _MacroEquation(
                  calculation: NutritionMacroCalculation(field.key, meals),
                  label: field.value),
            const Divider(),
            Text(
                'Từ nguyên liệu: cộng (khối lượng nguyên liệu theo g ÷ 100 × '
                'dưỡng chất trên 100 g × hệ số phần ăn được × hệ số chế biến).',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
                'Các giá trị món ăn đã được tính theo định lượng và nguồn dữ liệu '
                'của công thức. Có thể xem nguyên liệu và nguồn trong chi tiết từng món. '
                'Đây là tổng thực đơn, chưa phải lượng thực tế đã ăn hay nhu cầu của cơ thể.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _MacroEquation extends StatelessWidget {
  const _MacroEquation({required this.calculation, required this.label});
  final NutritionMacroCalculation calculation;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.compact),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          for (final meal in calculation.meals)
            Text(
                '${meal.name.isEmpty ? 'Món chưa có tên' : meal.name}: '
                '${calculation.amountLabel(meal)}',
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(calculation.equation,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.primary)),
        ]),
      );
}
