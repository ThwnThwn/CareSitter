import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/features/promotions/data/models/promotion_model.dart';
import 'package:caresitter_customer/features/promotions/presentation/controllers/active_promotions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookingVoucherList extends ConsumerWidget {
  const BookingVoucherList({
    super.key,
    required this.serviceId,
    required this.selectedCode,
    required this.onSelect,
  });

  final String? serviceId;
  final String selectedCode;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotions = ref.watch(activePromotionsProvider);
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ưu đãi cho lịch này', style: theme.titleSmall),
        const SizedBox(height: AppSpacing.compact),
        promotions.when(
          skipLoadingOnRefresh: false,
          loading: () => const Row(children: [
            SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('Đang tải ưu đãi…')),
          ]),
          error: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Không tải được danh sách ưu đãi.'),
              TextButton(
                onPressed: () => ref.invalidate(activePromotionsProvider),
                child: const Text('Tải lại ưu đãi'),
              ),
            ],
          ),
          data: (items) {
            final available = items
                .where((item) =>
                    item.eligibleServiceIds.isEmpty ||
                    item.eligibleServiceIds.contains(serviceId))
                .toList();
            if (available.isEmpty) {
              return const Text('Chưa có ưu đãi cho dịch vụ này.');
            }
            return Column(children: [
              for (final item in available)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _VoucherOption(
                    key: ValueKey(item.id),
                    item: item,
                    selected: item.code.toUpperCase() == selectedCode,
                    onTap: onSelect == null ? null : () => onSelect!(item.code),
                  ),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

class _VoucherOption extends StatelessWidget {
  const _VoucherOption({
    super.key,
    required this.item,
    required this.selected,
    this.onTap,
  });

  final PromotionModel item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final borderRadius = BorderRadius.circular(AppRadius.control);
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? AppColors.primaryContainer : AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.compact),
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_outlined,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.compact),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.badgeText.isEmpty ? item.code : item.badgeText,
                          style: theme.titleSmall
                              ?.copyWith(color: AppColors.primaryDark)),
                      Text(item.title, style: theme.bodyMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        [
                          item.code,
                          if (item.minOrderAmount > 0)
                            'Đơn từ ${formatVnd(item.minOrderAmount)}',
                          if (item.firstPaidBookingOnly)
                            'Đơn thanh toán đầu tiên',
                          'Đến ${formatDate(item.endsAt)}',
                        ].join(' · '),
                        style: theme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
