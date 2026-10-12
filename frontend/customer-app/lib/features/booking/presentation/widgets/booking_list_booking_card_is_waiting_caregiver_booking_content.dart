import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingListBookingCardIsWaitingCaregiverBookingContent
    extends StatelessWidget {
  const BookingListBookingCardIsWaitingCaregiverBookingContent(
      {super.key, required this.isWaitingCaregiver, required this.booking});
  final bool isWaitingCaregiver;
  final BookingModel booking;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    isWaitingCaregiver
                        ? 'Hệ thống đang ghép chăm sóc viên'
                        : (booking.caregiverName ?? 'Chăm sóc viên'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: isWaitingCaregiver
                            ? AppColors.warning
                            : AppColors.textPrimary,
                        fontSize: AppFontSizes.s13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                if (!isWaitingCaregiver) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.verified_rounded,
                      color: AppColors.primary, size: 12),
                ],
              ],
            ),
            Text(
              booking.serviceName ?? 'Dịch vụ chăm sóc',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s11),
            ),
          ],
        ),
      );
}
