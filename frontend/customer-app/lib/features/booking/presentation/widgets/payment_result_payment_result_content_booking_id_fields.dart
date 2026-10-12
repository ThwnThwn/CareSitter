import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class PaymentResultPaymentResultContentBookingIdFields extends StatelessWidget {
  const PaymentResultPaymentResultContentBookingIdFields(
      {super.key, required this.bookingId});
  final String? bookingId;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.inset),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.control),
                Expanded(
                  child: Text(
                    'Mã lịch hẹn',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Text(
                  '${bookingId!.substring(0, bookingId!.length.clamp(0, 8)).toUpperCase()}…',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ]);
}
