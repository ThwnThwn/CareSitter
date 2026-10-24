import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/care_timeline_timeline_item_is_last_event_content.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/care_timeline_timeline_item_event_is_last_fields.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/care_timeline_timeline_event.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final events = _buildEvents(bk);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nhật ký hỗ trợ'),
        leading:
            AppBackButton(fallbackRoute: AppRoutes.bookingDetail(bookingId)),
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.cardBackground,
            child: Row(children: [
              CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(bk.caregiverAvatar ?? bk.caregiverInitials,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: AppFontSizes.s11,
                          fontWeight: FontWeight.w800))),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(bk.caregiverName ?? 'Người chăm sóc',
                        style: const TextStyle(
                            fontSize: AppFontSizes.s14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('${bk.date} · ${bk.time}',
                        style: const TextStyle(
                            fontSize: AppFontSizes.s12,
                            color: AppColors.textSecondary)),
                  ])),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.control, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.compact)),
                child: Text(bk.duration,
                    style: const TextStyle(
                        fontSize: AppFontSizes.s12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Timeline
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: events.length,
              itemBuilder: (_, i) =>
                  _buildTimelineItem(events[i], i == events.length - 1),
            ),
          ),
        ],
      ),
    );
  }

  List<CareTimelineTimelineEvent> _buildEvents(BookingModel bk) {
    if (bk.tasks.isEmpty) {
      return [
        CareTimelineTimelineEvent(
          'Bắt đầu',
          'Check-in ca chăm sóc',
          bk.actualStart != null
              ? 'Caregiver đã có mặt và bắt đầu ca trực.'
              : 'Đang chờ caregiver check-in tại địa chỉ.',
          Icons.login_outlined,
          bk.actualStart != null ? AppColors.success : AppColors.warning,
          bk.actualStart != null,
        ),
        CareTimelineTimelineEvent(
          'Ca trực',
          'Thực hiện các hoạt động chăm sóc',
          bk.status == 'in_progress' || bk.status == 'completed'
              ? 'Caregiver đang thực hiện nhiệm vụ chăm sóc.'
              : 'Chưa bắt đầu.',
          Icons.task_alt,
          bk.status == 'in_progress' || bk.status == 'completed'
              ? AppColors.success
              : AppColors.warning,
          bk.status == 'in_progress' || bk.status == 'completed',
        ),
        CareTimelineTimelineEvent(
          'Kết thúc',
          'Check-out & Báo cáo',
          bk.isCompleted
              ? 'Ca chăm sóc đã hoàn tất thành công.'
              : 'Dự kiến khi hết thời gian ca trực.',
          Icons.logout_outlined,
          bk.isCompleted ? AppColors.success : AppColors.warning,
          bk.isCompleted,
        ),
      ];
    }

    return bk.tasks.asMap().entries.map((entry) {
      final task = entry.value;
      final isFirst = entry.key == 0;
      final isLast = entry.key == bk.tasks.length - 1;
      final title = task.title as String? ?? 'Nhiệm vụ ${entry.key + 1}';
      final isCompleted = (task.isCompleted as bool?) ?? false;
      return CareTimelineTimelineEvent(
        'B${entry.key + 1}',
        title,
        isCompleted
            ? 'Caregiver đã cập nhật hoàn thành nhiệm vụ.'
            : 'Đang chờ caregiver cập nhật trong ca chăm sóc.',
        isFirst
            ? Icons.login_outlined
            : isLast
                ? Icons.logout_outlined
                : Icons.task_alt,
        isCompleted ? AppColors.success : AppColors.warning,
        isCompleted,
      );
    }).toList(growable: false);
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
