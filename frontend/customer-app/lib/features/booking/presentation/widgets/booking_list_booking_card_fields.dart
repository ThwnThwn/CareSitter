import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingListBookingCardFields extends StatelessWidget {
  const BookingListBookingCardFields(
      {super.key, required this.callbackAction1});
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.control),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: callbackAction1,
                icon: const Icon(Icons.star_outline, size: 15),
                label: const Text('Đánh giá dịch vụ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.control),
                  minimumSize: Size.zero,
                ),
              ),
            ),
          ]);
}
