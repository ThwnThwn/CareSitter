import 'package:caresitter_customer/features/home/presentation/widgets/activity_recent_row_fields.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityRecentRowIsCancelledBookingContent extends StatelessWidget {
  const ActivityRecentRowIsCancelledBookingContent(
      {super.key,
      required this.isCancelled,
      required this.booking,
      required this.status,
      required this.callbackAction2});
  final bool isCancelled;
  final BookingModel booking;
  final String status;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCancelled)
              const Text(
                'Đã huỷ',
                style: TextStyle(
                  color: AppColors.legacyError,
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              booking.caregiverName ?? 'Người chăm sóc',
              style: TextStyle(
                color: isCancelled
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                fontSize: AppFontSizes.s15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.micro),
            Text(
              '${booking.serviceName ?? "Dịch vụ chăm sóc"} • Cho: ${booking.beneficiaryName ?? "Người thân"}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            Text(
              '${booking.time} • ${booking.date}',
              style: const TextStyle(
                  color: AppColors.textHint, fontSize: AppFontSizes.s11),
            ),
            if (!isCancelled && status == 'completed')
              ActivityRecentRowFields(callbackAction1: callbackAction2),
          ],
        ),
      );
}
