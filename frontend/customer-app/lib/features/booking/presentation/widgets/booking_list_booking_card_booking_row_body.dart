import 'package:caresitter_customer/core/theme/app_colors.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingListBookingCardBookingRowBody extends StatelessWidget {
  const BookingListBookingCardBookingRowBody(
      {super.key, required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              booking.date,
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
