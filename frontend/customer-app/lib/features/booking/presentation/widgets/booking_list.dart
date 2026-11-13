import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/domain/booking_status_rules.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'booking_card.dart';
import 'booking_list_screen_empty_state.dart';

class BookingList extends ConsumerWidget {
  const BookingList({super.key, required this.category});
  final BookingListCategory category;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingStoreProvider);
    final now = DateTime.now();
    final filtered = bookings
        .where((b) => BookingStatusRules.belongsToList(
            category, b.presentationStatusAt(now), b.caregiverId != null))
        .toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(bookingStoreProvider.notifier).refresh(),
      child: filtered.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.lg, AppSpacing.md, 120),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 144,
                  ),
                  child: const BookingListScreenEmptyState(),
                ),
              ),
            )
          : ListView.separated(
              key: PageStorageKey(category),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.compact),
              itemBuilder: (context, index) => FadeSlideStaggered(
                key: ValueKey(filtered[index].id),
                index: index,
                child: BookingCard(booking: filtered[index]),
              ),
            ),
    );
  }
}
