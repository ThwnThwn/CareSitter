import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../data/models/booking_meal_model.dart';
import '../../data/models/booking_meal_plan_model.dart';
import '../../data/models/booking_meal_record_model.dart';
import '../models/booking_meal_copy.dart';

class BookingMealDay extends StatelessWidget {
  const BookingMealDay({
    super.key,
    required this.plan,
    required this.records,
    required this.onRecord,
    required this.onCorrect,
    required this.disabled,
  });
  final BookingMealPlanModel plan;
  final List<BookingMealRecordModel> records;
  final ValueChanged<BookingMealModel> onRecord;
  final ValueChanged<BookingMealRecordModel> onCorrect;
  final bool disabled;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: true,
        title: Text(mealDateLabel(plan.plannedDate)),
        subtitle: Text(plan.isStale
            ? 'Chờ gia đình chia sẻ lại'
            : 'Thực đơn gia đình đã chia sẻ'),
        children: [
          if (plan.isStale)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.compact),
              child: Text(
                  'Thông tin chăm sóc đã thay đổi. Hãy dùng thực đơn mới sau khi gia đình chia sẻ lại.'),
            ),
          if (plan.canUse)
            for (final meal in plan.meals)
              _MealDetails(
                meal: meal,
                onRecord: plan.canRecord &&
                        !disabled &&
                        !records
                            .any((record) => record.mealType == meal.mealType)
                    ? () => onRecord(meal)
                    : null,
              ),
          for (final record in records)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                      '${mealTypeLabel(record.mealType)} · ${mealOutcomeLabels[record.outcome] ?? 'Đã ghi nhận'}',
                      style: Theme.of(context).textTheme.titleSmall),
                  if (record.note != null) Text(record.note!),
                  if (record.canCorrect)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: disabled ? null : () => onCorrect(record),
                        child: const Text('Đính chính'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
}

class _MealDetails extends StatelessWidget {
  const _MealDetails({required this.meal, this.onRecord});
  final BookingMealModel meal;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(meal.name),
        subtitle:
            Text('${mealTypeLabel(meal.mealType)} · ${meal.servings} phần'),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meal.ingredients.isNotEmpty) ...[
                  Text('Nguyên liệu',
                      style: Theme.of(context).textTheme.titleSmall),
                  for (final item in meal.ingredients)
                    Text('${item.name} · ${item.amount} ${item.unit}'),
                ],
                if (meal.preparationSteps.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Cách chuẩn bị',
                      style: Theme.of(context).textTheme.titleSmall),
                  for (final step in meal.preparationSteps) Text(step),
                ],
                if (meal.allergens.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text('Dị nguyên trong món: ${meal.allergens.join(', ')}'),
                ],
                if (onRecord != null)
                  OutlinedButton(
                      onPressed: onRecord,
                      child: const Text('Ghi nhận bữa ăn')),
              ],
            ),
          ),
        ],
      );
}
