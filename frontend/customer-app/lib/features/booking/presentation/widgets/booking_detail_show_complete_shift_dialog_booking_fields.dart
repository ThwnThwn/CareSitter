import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingDetailShowCompleteShiftDialogBookingFields
    extends StatelessWidget {
  const BookingDetailShowCompleteShiftDialogBookingFields(
      {super.key, required this.booking});
  final BookingModel booking;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn xác nhận ca chăm sóc của ${booking.caregiverName} đã hoàn tất?',
            style: const TextStyle(
                fontSize: AppFontSizes.s14,
                color: AppColors.textPrimary,
                height: 1.5),
          ),
          const SizedBox(height: AppSpacing.compact),
          Container(
            padding: const EdgeInsets.all(AppSpacing.compact),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.compact),
              border:
                  Border.all(color: AppColors.success.withValues(alpha: 0.25)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.success),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Nếu bạn không xác nhận, hệ thống sẽ tự động hoàn tất sau 24 giờ kể từ khi yêu cầu checkout được gửi.',
                    style: TextStyle(
                        fontSize: AppFontSizes.s11,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
