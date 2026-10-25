import 'package:caregiver_app/core/utils/date_formatter.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';

class ShiftTimerChip extends ConsumerWidget {
  const ShiftTimerChip({super.key, required this.bookingId});
  final String bookingId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed =
        ref.watch(shiftActiveProvider(bookingId).select((s) => s.elapsed));
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.tight,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            formatDuration(elapsed),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: AppFontSizes.s11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
