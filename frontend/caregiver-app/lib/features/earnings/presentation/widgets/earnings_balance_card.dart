import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class EarningsBalanceCard extends StatelessWidget {
  const EarningsBalanceCard({super.key, required this.balance});
  final double balance;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Số dư khả dụng',
            style: TextStyle(
              fontSize: AppFontSizes.s14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.compact),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  formatVnd(balance, separator: ',', suffix: '', round: true),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppFontSizes.s32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.sm),
                child: Text('₫',
                    style: TextStyle(
                        fontSize: AppFontSizes.s16, color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/earnings/withdraw'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              child: const Text('Rút tiền'),
            ),
          ),
        ],
      ),
    );
  }
}
