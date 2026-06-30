import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/mock/mock_data.dart';
import '../../booking/application/booking_store.dart';

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
        leading: AppBackButton(fallbackRoute: '/bookings/$bookingId'),
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.cardBackground,
            child: Row(children: [
              CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(bk.caregiverAvatar,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(bk.caregiverName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('${bk.date} · ${bk.time}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ])),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(bk.duration,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Timeline
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (_, i) =>
                  _buildTimelineItem(events[i], i == events.length - 1),
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineEvent> _buildEvents(MockBooking bk) {
    return bk.tasks.asMap().entries.map((entry) {
      final task = entry.value;
      final isFirst = entry.key == 0;
      final isLast = entry.key == bk.tasks.length - 1;
      return _TimelineEvent(
        'B${entry.key + 1}',
        task.title,
        task.isCompleted
            ? 'Caregiver đã cập nhật hoàn thành nhiệm vụ.'
            : 'Đang chờ caregiver cập nhật trong ca chăm sóc.',
        isFirst
            ? Icons.login_outlined
            : isLast
                ? Icons.logout_outlined
                : Icons.task_alt,
        task.isCompleted ? AppColors.success : AppColors.warning,
        task.isCompleted,
      );
    }).toList(growable: false);
  }

  Widget _buildTimelineItem(_TimelineEvent event, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time
        SizedBox(
          width: 52,
          child: Text(event.time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    event.isDone ? AppColors.textPrimary : AppColors.textHint,
              )),
        ),

        // Line + dot
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: event.isDone
                    ? event.color.withValues(alpha: 0.15)
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(
                    color: event.isDone ? event.color : AppColors.border,
                    width: 2),
              ),
              child: Icon(event.icon,
                  size: 16,
                  color: event.isDone ? event.color : AppColors.textHint),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: event.isDone
                    ? event.color.withValues(alpha: 0.2)
                    : AppColors.border,
              ),
          ],
        ),

        const SizedBox(width: 12),

        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: event.isDone
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    )),
                const SizedBox(height: 4),
                Text(event.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: event.isDone
                          ? AppColors.textSecondary
                          : AppColors.textHint,
                      height: 1.4,
                    )),
                if (!event.isDone && event.title != 'Check-out (dự kiến)') ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Đang diễn ra',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineEvent {
  final String time;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDone;

  const _TimelineEvent(this.time, this.title, this.description, this.icon,
      this.color, this.isDone);
}
