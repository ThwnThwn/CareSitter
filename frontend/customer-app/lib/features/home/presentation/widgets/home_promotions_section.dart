import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/promotions/presentation/controllers/active_promotions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_promo_card.dart';

class HomePromotionsSection extends ConsumerWidget {
  const HomePromotionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promotions = ref.watch(activePromotionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ưu đãi & Khuyến mãi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: AppSpacing.compact),
        promotions.when(
          skipLoadingOnRefresh: false,
          loading: () => const Text('Đang tải ưu đãi…'),
          error: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chưa tải được ưu đãi.'),
              TextButton(
                onPressed: () => ref.invalidate(activePromotionsProvider),
                child: const Text('Tải lại'),
              ),
            ],
          ),
          data: (items) => items.isEmpty
              ? const Text('Hiện chưa có ưu đãi đang hoạt động.')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: AppSpacing.control,
                    children: [
                      for (final promotion in items)
                        HomePromoCard(
                          key: ValueKey(promotion.id),
                          promotion: promotion,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
