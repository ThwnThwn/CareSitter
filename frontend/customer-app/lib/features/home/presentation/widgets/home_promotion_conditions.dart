import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/features/catalog/presentation/controllers/service_controller.dart';
import 'package:caresitter_customer/features/promotions/data/models/promotion_model.dart';

class HomePromotionConditions extends ConsumerWidget {
  const HomePromotionConditions({super.key, required this.promotion});
  final PromotionModel promotion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = promotion.eligibleServiceIds.isEmpty
        ? null
        : ref.watch(serviceStoreProvider).valueOrNull;
    final names = {for (final s in services ?? []) s.id: s.name};
    final serviceNames = promotion.eligibleServiceIds
        .map((id) => names[id])
        .whereType<String>()
        .toList();
    final missingNames =
        promotion.eligibleServiceIds.length - serviceNames.length;
    final description = promotion.description?.trim();
    final lines = <String>{
      if (promotion.minOrderAmount > 0)
        'Đơn tối thiểu ${formatVnd(promotion.minOrderAmount)}',
      if (promotion.maxDiscountAmount case final cap?)
        'Giảm tối đa ${formatVnd(cap)}',
      if (promotion.firstPaidBookingOnly) 'Áp dụng cho đơn thanh toán đầu tiên',
      if (promotion.perCustomerUsageLimit case final count?)
        'Tối đa $count lượt mỗi khách',
      if (serviceNames.isNotEmpty)
        'Dịch vụ áp dụng: ${serviceNames.join(', ')}'
            '${missingNames > 0 ? ' và $missingNames dịch vụ khác' : ''}'
      else if (missingNames > 0)
        'Áp dụng cho một số dịch vụ',
      ...promotion.terms,
    };
    lines.remove(promotion.summary.trim());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (description != null &&
          description.isNotEmpty &&
          description != promotion.summary.trim())
        Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(description)),
      if (lines.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text('Điều kiện áp dụng',
              style: Theme.of(context).textTheme.titleSmall),
        ),
      for (final line in lines)
        Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(line)),
    ]);
  }
}
