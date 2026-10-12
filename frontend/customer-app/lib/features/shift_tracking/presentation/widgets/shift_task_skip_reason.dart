import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTaskSkipReason extends StatelessWidget {
  const ShiftTaskSkipReason({super.key, required this.task});
  final CareTaskModel task;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm, left: 38),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.control, vertical: AppSpacing.tight),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.amberBorder, width: 0.6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.tight),
                  Expanded(
                    child: Text(
                      'Lý do: ${task.skipReason}',
                      style: const TextStyle(
                        fontSize: AppFontSizes.s11,
                        color: AppColors.brown,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]);
}
