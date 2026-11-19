import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'booking_payment_row.dart';

class BookingPriceBreakdown extends StatelessWidget {
  const BookingPriceBreakdown({
    super.key,
    required this.grossAmount,
    required this.discountAmount,
  });

  final int grossAmount, discountAmount;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          BookingPaymentRow(label: 'Giá trước ưu đãi', amount: grossAmount),
          if (discountAmount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            BookingPaymentRow(label: 'Giảm giá', amount: -discountAmount),
          ],
        ],
      );
}
