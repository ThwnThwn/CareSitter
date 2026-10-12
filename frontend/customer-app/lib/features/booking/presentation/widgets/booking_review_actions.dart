import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingReviewActions extends StatelessWidget {
  const BookingReviewActions(
      {super.key,
      required this.booking,
      required this.action8,
      required this.buildStatusBanner,
      required this.action9});
  final BookingModel booking;
  final void Function() action8;
  final Widget Function(String) buildStatusBanner;
  final void Function() action9;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!booking.isReviewed)
              ElevatedButton.icon(
                onPressed: action8,
                icon: const Icon(Icons.star_outline),
                label: const Text('Đánh giá dịch vụ'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52)),
              )
            else
              buildStatusBanner('Bạn đã đánh giá ca chăm sóc này.'),
            const SizedBox(height: AppSpacing.control),
            OutlinedButton.icon(
              onPressed: action9,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Đặt lịch lại'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
            ),
          ]);
}
