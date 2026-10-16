import 'package:caresitter_customer/features/wallet/presentation/widgets/wallet_presentation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/wallet/presentation/controllers/wallet_controller.dart';

class WalletTransactionTile extends StatelessWidget {
  final WalletTransaction transaction;

  const WalletTransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.direction == 'CREDIT';
    final info = walletTransactionInfo(transaction.type);
    final amountColor = isCredit ? AppColors.primary : AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inset, vertical: AppSpacing.tight),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: info.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(info.icon, color: info.color, size: 21),
        ),
        title: Text(
          info.label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppFontSizes.s14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          walletFormatDate(transaction.createdAt),
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: AppFontSizes.s12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isCredit ? '+' : '-'}${walletFormatCurrency(transaction.amount)}',
              style: TextStyle(
                color: amountColor,
                fontSize: AppFontSizes.s14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.micro),
            Text(
              walletStatusLabel(transaction.status),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s11),
            ),
          ],
        ),
      ),
    );
  }
}
