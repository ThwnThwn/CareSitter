import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTaskNotes extends StatelessWidget {
  const ShiftTaskNotes({super.key, required this.task});
  final CareTaskModel task;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.tiny),
            Text(
              task.description!,
              style: const TextStyle(
                fontSize: AppFontSizes.s11,
                color: AppColors.textSecondary,
              ),
            ),
          ]);
}
