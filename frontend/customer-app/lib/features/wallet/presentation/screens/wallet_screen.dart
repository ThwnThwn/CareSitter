export 'package:caresitter_customer/features/wallet/presentation/widgets/wallet_presentation_helpers.dart';
import 'package:caresitter_customer/features/wallet/presentation/widgets/wallet_balance_card.dart';
import 'package:caresitter_customer/features/wallet/presentation/widgets/wallet_transaction_tile.dart';
import 'package:caresitter_customer/features/wallet/presentation/widgets/wallet_wallet_empty_state.dart';
import 'package:caresitter_customer/features/wallet/presentation/widgets/wallet_wallet_load_error.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';

import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/wallet/presentation/controllers/wallet_controller.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(customerWalletProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ví CareSitter'),
        leading: const AppBackButton(fallbackRoute: AppRoutes.settings),
      ),
      body: wallet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => WalletWalletLoadError(
          onRetry: () => ref.read(customerWalletProvider.notifier).refresh(),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(customerWalletProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
            children: [
              WalletBalanceCard(wallet: data),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Lịch sử giao dịch',
                style: TextStyle(
                  fontSize: AppFontSizes.s17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.control),
              if (data.transactions.isEmpty)
                const WalletWalletEmptyState()
              else
                ...data.transactions.map(
                  (transaction) =>
                      WalletTransactionTile(transaction: transaction),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
