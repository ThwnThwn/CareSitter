import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class HomeAppointmentSchedule extends StatelessWidget {
  const HomeAppointmentSchedule(
      {super.key, required this.dateStr, required this.booking});
  final String dateStr;
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 12,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '$dateStr · ${booking.time}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.s11,
              ),
            ),
          ),
        ],
      );
}
