import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_task_ad_hoc_badge.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_task_required_badge.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_task_notes.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTaskIdentity extends StatelessWidget {
  const ShiftTaskIdentity(
      {super.key,
      required this.isDone,
      required this.isSkipped,
      required this.iconForTask,
      required this.task});
  final bool isDone;
  final bool isSkipped;
  final IconData Function(String) iconForTask;
  final CareTaskModel task;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(
                top: AppSpacing.hairline, right: AppSpacing.control),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? AppColors.success
                  : isSkipped
                      ? AppColors.amber
                      : AppColors.surface,
              border: Border.all(
                color: isDone
                    ? AppColors.success
                    : isSkipped
                        ? AppColors.warning
                        : AppColors.border,
                width: 1.5,
              ),
            ),
            child: isDone
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : isSkipped
                    ? const Icon(Icons.remove_rounded,
                        size: 16, color: Colors.white)
                    : Icon(
                        iconForTask(task.title),
                        size: 14,
                        color: AppColors.textHint,
                      ),
          ),
          // Title and badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: AppFontSizes.s13,
                          fontWeight:
                              isDone ? FontWeight.w500 : FontWeight.w600,
                          color: isSkipped
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                          decoration:
                              isSkipped ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (task.isAdHoc) const ShiftTaskAdHocBadge(),
                    if (task.isRequired && !task.isTerminal)
                      const ShiftTaskRequiredBadge(),
                  ],
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  ShiftTaskNotes(task: task),
              ],
            ),
          ),
        ],
      );
}
