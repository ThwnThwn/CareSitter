import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/refunds/presentation/controllers/refunds_controller.dart';
import 'package:caresitter_customer/features/refunds/presentation/widgets/refund_card.dart';

class RefundHistoryScreen extends ConsumerWidget {
  const RefundHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refunds = ref.watch(refundsProvider);
    Future<void> refresh() => ref.read(refundsProvider.notifier).refresh();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch sử hoàn tiền'),
        leading: const AppBackButton(fallbackRoute: '/settings'),
      ),
      body: refunds.when(
        loading: () => const _RefundLoading(),
        error: (_, __) => _RefundError(onRetry: refresh),
        data: (items) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              const _RefundPolicyNote(),
              const SizedBox(height: AppSpacing.md),
              if (items.isEmpty)
                const _RefundEmpty()
              else
                for (var index = 0; index < items.length; index++) ...[
                  RefundCard(
                    refund: items[index],
                    onRetry: refresh,
                    onSupport: () => context.push('/settings/support'),
                  ),
                  if (index != items.length - 1)
                    const SizedBox(height: AppSpacing.compact),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RefundPolicyNote extends StatelessWidget {
  const _RefundPolicyNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child:
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.verified_user_outlined, color: AppColors.primary),
          SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Text(
              'Tiền được hoàn về đúng phương thức đã thanh toán. “Thử lại” chỉ cập nhật trạng thái, không tạo giao dịch hoàn mới.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s13,
                height: 1.45,
              ),
            ),
          ),
        ]),
      );
}

class _RefundLoading extends StatelessWidget {
  const _RefundLoading();

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.compact),
        itemBuilder: (_, __) => Container(
          height: 166,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
}

class _RefundError extends StatelessWidget {
  const _RefundError({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            const Text('Chưa tải được lịch sử hoàn tiền',
                style: TextStyle(
                  fontSize: AppFontSizes.s16,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ]),
        ),
      );
}

class _RefundEmpty extends StatelessWidget {
  const _RefundEmpty();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(children: [
          Icon(Icons.receipt_long_outlined,
              size: 52, color: AppColors.textSecondary),
          SizedBox(height: AppSpacing.md),
          Text('Chưa có yêu cầu hoàn tiền',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.w700,
              )),
          SizedBox(height: AppSpacing.xs),
          Text('Các khoản hoàn sẽ xuất hiện tại đây để bạn theo dõi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
        ]),
      );
}
