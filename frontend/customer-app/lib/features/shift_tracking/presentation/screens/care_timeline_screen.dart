import '../controllers/booking_timeline_controller.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import '../../data/models/booking_timeline_event_model.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/care_timeline_timeline_item_is_last_event_content.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/care_timeline_timeline_item_event_is_last_fields.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/care_timeline_timeline_event.dart';
import '../widgets/care_timeline_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class CareTimelineScreen extends ConsumerWidget {
  final String bookingId;
  const CareTimelineScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches =
        ref.watch(bookingStoreProvider).where((b) => b.id == bookingId);
    if (matches.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Không tìm thấy booking')));
    }
    final bk = matches.first;
    final timeline = ref.watch(bookingTimelineProvider(bookingId));
    final events = timeline.when(
        data: _buildEvents,
        loading: () => [
              const CareTimelineTimelineEvent(
                  '',
                  'Đang tải nhật ký',
                  'Đang lấy các ghi nhận thực tế của ca.',
                  Icons.history,
                  AppColors.textSecondary,
                  false)
            ],
        error: (_, __) => [
              const CareTimelineTimelineEvent(
                  '',
                  'Chưa tải được nhật ký',
                  'Vui lòng kéo xuống để thử lại.',
                  Icons.info_outline,
                  AppColors.warning,
                  false)
            ]);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nhật ký hỗ trợ'),
        leading:
            AppBackButton(fallbackRoute: AppRoutes.bookingDetail(bookingId)),
        actions: [
          IconButton(
            tooltip: 'Bữa ăn trong ca',
            onPressed: () => context.push(AppRoutes.bookingMeals(bookingId)),
            icon: const Icon(Icons.restaurant_menu_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          CareTimelineSummary(
              avatar: bk.caregiverAvatar ?? bk.caregiverInitials,
              name: bk.caregiverName ?? 'Người chăm sóc',
              schedule: '${bk.date} · ${bk.time}',
              duration: bk.duration),
          const Divider(height: 1),

          // Timeline
          Expanded(
            child: RefreshIndicator(
                onRefresh: () => ref
                    .refresh(bookingTimelineProvider(bookingId).future)
                    .then<void>((_) {}),
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: events.length,
                  itemBuilder: (_, i) =>
                      _buildTimelineItem(events[i], i == events.length - 1),
                )),
          ),
        ],
      ),
    );
  }

  List<CareTimelineTimelineEvent> _buildEvents(
      List<BookingTimelineEventModel> events) {
    if (events.isEmpty) {
      return [
        const CareTimelineTimelineEvent(
            '',
            'Chưa có ghi nhận',
            'Các cập nhật sẽ xuất hiện khi ca được thực hiện.',
            Icons.history,
            AppColors.textSecondary,
            false)
      ];
    }
    return events
        .map((event) => CareTimelineTimelineEvent(
            formatClock(event.recordedAt.toUtc().add(const Duration(hours: 7))),
            event.title ?? 'Cập nhật ca chăm sóc',
            event.note ?? '',
            event.eventType == 'SOS' ? Icons.warning_amber : Icons.task_alt,
            event.eventType == 'SOS'
                ? AppColors.error
                : event.eventType == 'CHECKIN_OUTSIDE_GEOFENCE'
                    ? AppColors.warning
                    : AppColors.success,
            true))
        .toList(growable: false);
  }

  Widget _buildTimelineItem(CareTimelineTimelineEvent event, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time
        SizedBox(
          width: 52,
          child: Text(event.time,
              style: TextStyle(
                fontSize: AppFontSizes.s12,
                fontWeight: FontWeight.w700,
                color:
                    event.isDone ? AppColors.textPrimary : AppColors.textHint,
              )),
        ),

        // Line + dot
        CareTimelineTimelineItemEventIsLastFields(event: event, isLast: isLast),

        const SizedBox(width: AppSpacing.compact),

        // Content
        CareTimelineTimelineItemIsLastEventContent(
            isLast: isLast, event: event),
      ],
    );
  }
}
