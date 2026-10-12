import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreenNeedsReviewBanner extends StatelessWidget {
  const ShiftTrackingScreenNeedsReviewBanner({super.key, required this.bk});
  final BookingModel bk;
  @override
  Widget build(BuildContext context) {
    final skippedRequiredCount =
        bk.tasks.where((t) => t.isRequired && t.isSkipped).length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.inset),
      decoration: BoxDecoration(
        color: AppColors.amberSurface, // amber.shade50
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.amberBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ca trực cần xem lại',
                  style: TextStyle(
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  skippedRequiredCount > 0
                      ? 'Có $skippedRequiredCount công việc bắt buộc không thể thực hiện trong ca. Người chăm sóc đã ghi rõ lý do bên dưới để gia đình tiện theo dõi.'
                      : 'Ca trực này có các công việc cần lưu ý xem xét.',
                  style: const TextStyle(
                    fontSize: AppFontSizes.s12,
                    color: AppColors.amberText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
