import 'package:caregiver_app/features/earnings/presentation/widgets/earnings_balance_card.dart';
import 'package:caregiver_app/features/earnings/presentation/widgets/earnings_transaction_list.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/router/navigation_helpers.dart';
import 'package:caregiver_app/features/earnings/data/models/earning_model.dart';
import 'package:caregiver_app/features/earnings/presentation/controllers/earnings_controller.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(earningsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thu nhập'),
        leading: const AppBackButton(fallbackRoute: '/home'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(context, earnings.balance),
            const SizedBox(height: AppSpacing.xl),
            const Text(
              'Lịch sử giao dịch',
              style: TextStyle(
                fontSize: AppFontSizes.s18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildTransactionList(earnings.transactions),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, double balance) =>
      EarningsBalanceCard(balance: balance);

  Widget _buildTransactionList(List<EarningTransaction> transactions) =>
      EarningsTransactionList(transactions: transactions);
}
