import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityActiveCardBookingPanelBody extends StatelessWidget {
  const ActivityActiveCardBookingPanelBody({super.key, required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inset, vertical: AppSpacing.control),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: AppSpacing.tight),
            Text(
              booking.time,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AppSpacing.md),
            const Icon(Icons.home_repair_service_outlined,
                color: Colors.white, size: 16),
            const SizedBox(width: AppSpacing.tight),
            Expanded(
              child: Text(
                booking.serviceName ?? 'Dịch vụ chăm sóc',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: AppFontSizes.s13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}
