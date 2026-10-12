import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class BookingListScreenBookingList extends StatelessWidget {
  const BookingListScreenBookingList(
      {super.key,
      required this.ref,
      required this.statuses,
      required this.buildEmptyState,
      required this.buildBookingCard});
  final WidgetRef ref;
  final List<String> statuses;
  final Widget Function() buildEmptyState;
  final Widget Function(BookingModel) buildBookingCard;
  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingStoreProvider);
    final now = DateTime.now();
    final filtered = bookings
        .where((b) => statuses.contains(b.presentationStatusAt(now)))
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
                  child: buildEmptyState(),
                ),
              ),
            )
          : ListView.separated(
              key: PageStorageKey(statuses.join(',')),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.compact),
              itemBuilder: (context, index) => FadeSlideStaggered(
                key: ValueKey(filtered[index].id),
                index: index,
                child: buildBookingCard(filtered[index]),
              ),
            ),
    );
  }
}
