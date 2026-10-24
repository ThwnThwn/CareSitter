import 'package:caresitter_customer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';

class BookingPaymentRow extends StatelessWidget {
  const BookingPaymentRow(
      {super.key, required this.label, required this.amount});
  final String label;
  final double amount;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
          flex: 3,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s13)),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(amount == 0 ? 'Miễn phí' : '${formatVnd(amount)}đ',
              textAlign: TextAlign.right,
              style: TextStyle(
                  color:
                      amount == 0 ? AppColors.success : AppColors.textPrimary,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w500)),
        ),
      ]);
}
