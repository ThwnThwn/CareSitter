import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingListBookingCardBookingRow extends StatelessWidget {
  const BookingListBookingCardBookingRow({super.key, required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.access_time_outlined,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${booking.time} (${booking.duration})',
              maxLines: 2,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.s12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
}
