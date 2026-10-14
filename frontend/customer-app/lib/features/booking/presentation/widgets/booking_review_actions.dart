import 'booking_detail_screen_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingReviewActions extends StatelessWidget {
  const BookingReviewActions(
      {super.key,
      required this.booking,
      required this.onReview,
      required this.onRebook});
  final BookingModel booking;
  final void Function() onReview;
  final void Function() onRebook;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!booking.isReviewed)
              ElevatedButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.star_outline),
                label: const Text('Đánh giá dịch vụ'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52)),
              )
            else
              const BookingDetailScreenStatusBanner(
                  message: 'Bạn đã đánh giá ca chăm sóc này.'),
            const SizedBox(height: AppSpacing.control),
            OutlinedButton.icon(
              onPressed: onRebook,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Đặt lịch lại'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
            ),
          ]);
}
