import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftChecklistTask extends StatelessWidget {
  const ShiftChecklistTask({super.key, required this.task});
  final CareTaskModel task;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            task.isCompleted
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: task.isCompleted ? AppColors.primary : AppColors.textHint,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.control),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: AppFontSizes.s14,
                color: task.isCompleted
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
}
