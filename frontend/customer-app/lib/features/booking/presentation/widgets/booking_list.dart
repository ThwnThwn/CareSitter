import 'dart:math';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/booking_status_rules.dart';
import '../controllers/booking_controller.dart';
import '../controllers/booking_list_load_controller.dart';
import 'booking_card.dart';
import 'booking_list_screen_empty_state.dart';

const _listPadding =
    EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 120);

class BookingList extends ConsumerWidget {
  const BookingList({super.key, required this.category});
  final BookingListCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingStoreProvider);
    final loadState = ref.watch(bookingListLoadProvider);
    final refresh = ref.read(bookingStoreProvider.notifier).refresh;
    final now = DateTime.now();
    final filtered = bookings
        .where((booking) => BookingStatusRules.belongsToList(category,
            booking.presentationStatusAt(now), booking.caregiverId != null))
        .toList();

    if (filtered.isEmpty) {
      final content = switch (loadState) {
        BookingListLoadState.loading => const _BookingListLoading(),
        BookingListLoadState.failed => _BookingListError(onRetry: refresh),
        BookingListLoadState.ready => BookingListScreenEmptyState(
            category: category, hasBookings: bookings.isNotEmpty),
      };
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: refresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: _listPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight:
                      max(0.0, constraints.maxHeight - _listPadding.vertical)),
              child: Center(child: content),
            ),
          ),
        ),
      );
    }

    final showError = loadState == BookingListLoadState.failed;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: refresh,
      child: ListView.separated(
        key: PageStorageKey(category),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listPadding,
        itemCount: filtered.length + (showError ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.compact),
        itemBuilder: (context, index) {
          if (showError && index == 0) {
            return _BookingListError(onRetry: refresh, hasCachedData: true);
          }
          final bookingIndex = showError ? index - 1 : index;
          final booking = filtered[bookingIndex];
          return FadeSlideStaggered(
            key: ValueKey(booking.id),
            index: bookingIndex,
            child: BookingCard(
              booking: booking,
              scheduledWindowEnded: category == BookingListCategory.active &&
                  !now.isBefore(booking.scheduledEnd),
            ),
          );
        },
      ),
    );
  }
}

class _BookingListLoading extends StatelessWidget {
  const _BookingListLoading();

  @override
  Widget build(BuildContext context) => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSpacing.md),
          Text('Đang tải lịch hẹn…'),
        ],
      );
}

class _BookingListError extends StatelessWidget {
  const _BookingListError({required this.onRetry, this.hasCachedData = false});
  final VoidCallback onRetry;
  final bool hasCachedData;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              hasCachedData
                  ? 'Không cập nhật được lịch hẹn'
                  : 'Không tải được lịch hẹn',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      );
}
