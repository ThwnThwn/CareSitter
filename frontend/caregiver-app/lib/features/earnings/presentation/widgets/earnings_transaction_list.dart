import 'package:caregiver_app/features/earnings/presentation/widgets/earnings_transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import 'package:caregiver_app/features/earnings/data/models/earning_model.dart';

class EarningsTransactionList extends StatelessWidget {
  const EarningsTransactionList({super.key, required this.transactions});
  final List<EarningTransaction> transactions;
  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.lg),
        child: AppEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'Chưa có giao dịch',
          message: 'Thu nhập và các lần rút tiền sẽ hiển thị tại đây.',
        ),
      );
    }
    return Column(
      children: transactions.map((t) {
        final isIn = t.type == 'in';
        final amountColor = isIn ? AppColors.success : AppColors.error;
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: EarningsTransactionTile(
              amountColor: amountColor, isIn: isIn, t: t),
        );
      }).toList(),
    );
  }
}
