import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../application/wallet_store.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(customerWalletProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ví CareSitter'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: wallet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _WalletLoadError(
          onRetry: () => ref.read(customerWalletProvider.notifier).refresh(),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.read(customerWalletProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _BalanceCard(wallet: data),
              const SizedBox(height: 24),
              const Text(
                'Lịch sử giao dịch',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              if (data.transactions.isEmpty)
                const _WalletEmptyState()
              else
                ...data.transactions.map(
                  (transaction) => _TransactionTile(transaction: transaction),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final CustomerWallet wallet;

  const _BalanceCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Số dư khả dụng',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _formatCurrency(wallet.availableBalance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (wallet.pendingBalance > 0) ...[
            const SizedBox(height: 12),
            Text(
              'Đang xử lý: ${_formatCurrency(wallet.pendingBalance)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.direction == 'CREDIT';
    final info = _transactionInfo(transaction.type);
    final amountColor = isCredit ? AppColors.primary : AppColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: info.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(info.icon, color: info.color, size: 21),
        ),
        title: Text(
          info.label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _formatDate(transaction.createdAt),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isCredit ? '+' : '-'}${_formatCurrency(transaction.amount)}',
              style: TextStyle(
                color: amountColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _statusLabel(transaction.status),
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletEmptyState extends StatelessWidget {
  const _WalletEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 34, color: AppColors.textHint),
          SizedBox(height: 10),
          Text(
            'Chưa có giao dịch ví',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Các khoản hoàn tiền sẽ xuất hiện ở đây.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _WalletLoadError extends StatelessWidget {
  final VoidCallback onRetry;

  const _WalletLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 42, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text(
              'Không tải được thông tin ví',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

({String label, IconData icon, Color color}) _transactionInfo(String type) {
  switch (type) {
    case 'REFUND':
      return (
        label: 'Hoàn tiền dịch vụ',
        icon: Icons.reply_rounded,
        color: AppColors.primary,
      );
    case 'PAYOUT':
      return (
        label: 'Rút tiền',
        icon: Icons.south_east_rounded,
        color: AppColors.textSecondary,
      );
    default:
      return (
        label: 'Giao dịch ví',
        icon: Icons.receipt_long_outlined,
        color: AppColors.textSecondary,
      );
  }
}

String _statusLabel(String status) => switch (status) {
      'POSTED' => 'Hoàn tất',
      'PENDING' => 'Đang xử lý',
      'REVERSED' => 'Đã hoàn tác',
      _ => 'Đang cập nhật',
    };

String _formatCurrency(int amount) {
  final digits = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
  return '$digits\u0111';
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} • $hour:$minute';
}
