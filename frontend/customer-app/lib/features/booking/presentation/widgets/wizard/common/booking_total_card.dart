import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';

class BookingTotalCard extends StatelessWidget {
  const BookingTotalCard({super.key, required this.amount});
  final double? amount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text('Tổng giá trị booking',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(amount == null ? '---' : formatVnd(amount!, round: true),
                maxLines: 1,
                style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
