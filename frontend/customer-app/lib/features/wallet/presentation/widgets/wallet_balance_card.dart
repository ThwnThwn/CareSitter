import 'package:caresitter_customer/features/wallet/presentation/widgets/wallet_presentation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/wallet/presentation/controllers/wallet_controller.dart';

class WalletBalanceCard extends StatelessWidget {
  final CustomerWallet wallet;

  const WalletBalanceCard({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.section),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 22),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Số dư khả dụng',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSizes.s14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.inset),
          Text(
            walletFormatCurrency(wallet.availableBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppFontSizes.s30,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (wallet.pendingBalance > 0) ...[
            const SizedBox(height: AppSpacing.compact),
            Text(
              'Đang xử lý: ${walletFormatCurrency(wallet.pendingBalance)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: AppFontSizes.s13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
