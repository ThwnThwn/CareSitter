import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTaskCompletionTime extends StatelessWidget {
  const ShiftTaskCompletionTime({super.key, required this.task});
  final CareTaskModel task;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs, left: 38),
              child: Text(
                'Hoàn thành lúc ${task.completedAt!.hour.toString().padLeft(2, '0')}:${task.completedAt!.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: AppFontSizes.s10,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ]);
}
