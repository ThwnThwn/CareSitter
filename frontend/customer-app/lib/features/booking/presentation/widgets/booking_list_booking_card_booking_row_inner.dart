import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingListBookingCardBookingRowInner extends StatelessWidget {
  const BookingListBookingCardBookingRowInner(
      {super.key, required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.location_on_outlined,
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              booking.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s12),
            ),
          ),
        ],
      );
}
