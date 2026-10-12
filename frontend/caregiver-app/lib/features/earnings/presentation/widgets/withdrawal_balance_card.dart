import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';

/// Card hiển thị số dư khả dụng trên màn hình rút tiền.
class WithdrawalBalanceCard extends StatelessWidget {
  final double balance;

  const WithdrawalBalanceCard({
    super.key,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.section),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số dư khả dụng',
            style: TextStyle(
              color: Colors.white70,
              fontSize: AppFontSizes.s13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${formatVnd(balance, separator: ',', suffix: '', round: true)} đ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppFontSizes.s32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
