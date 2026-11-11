import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../models/nutrition_menu_overview_model.dart';
import 'nutrition_week_strip.dart';

class NutritionCalendarSection extends StatelessWidget {
  const NutritionCalendarSection({
    super.key,
    required this.overview,
    required this.onDateSelected,
  });

  final NutritionMenuOverviewModel overview;
  final ValueChanged<DateTime>? onDateSelected;

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: overview.plannedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày lập thực đơn',
    );
    if (context.mounted && selected != null) onDateSelected?.call(selected);
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lịch thực đơn',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed:
                    onDateSelected == null ? null : () => _pickDate(context),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(
                  '${overview.plannedDate.month}/${overview.plannedDate.year}',
                ),
              ),
            ],
          ),
          if (onDateSelected != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => onDateSelected!(DateTime.now()),
                child: const Text('Hôm nay'),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          NutritionWeekStrip(
            selected: overview.plannedDate,
            onSelected: onDateSelected,
          ),
        ],
      );
}
