import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_skipped_count.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreenProgressStrip extends StatelessWidget {
  const ShiftTrackingScreenProgressStrip(
      {super.key,
      required this.bk,
      required this.done,
      required this.total,
      required this.skippedCount,
      required this.pct});
  final BookingModel bk;
  final int done;
  final int total;
  final int skippedCount;
  final double pct;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.inset),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${bk.serviceName ?? "Dịch vụ"} • ${bk.duration}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: AppFontSizes.s12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$done / $total công việc hoàn thành',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSizes.s14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (skippedCount > 0)
                  ShiftTrackingSkippedCount(skippedCount: skippedCount),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.schedule, color: Colors.white, size: 16),
              const SizedBox(height: AppSpacing.xs),
              Text(
                bk.time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                bk.date,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: AppFontSizes.s11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
