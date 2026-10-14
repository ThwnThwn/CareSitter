import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_hour_marker.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_hour_label.dart';
import 'schedule_shift_card.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleTimeline extends StatelessWidget {
  const ScheduleTimeline(
      {super.key,
      required this.timelineScrollController,
      required this.dayShifts,
      required this.selectedDate});
  final ScrollController timelineScrollController;
  final List<TimelineShift> dayShifts;
  final DateTime selectedDate;
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: timelineScrollController,
      padding:
          const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.s100),
      itemCount: 24, // Hiển thị đủ 00:00 đến 23:00 trong ngày
      itemBuilder: (context, index) {
        final hour = index;
        final timeLabel = '${hour.toString().padLeft(2, '0')}:00';

        // Check if there's a shift starting at this hour
        final startingShift =
            dayShifts.where((s) => s.startHour == hour).toList();

        // Check if this hour is covered by a shift (for the green bar)
        final isShiftHour =
            dayShifts.any((s) => hour >= s.startHour && hour < s.endHour);

        // Current hour indicator
        final now = DateTime.now();
        final isCurrentHour =
            DateUtils.isSameDay(selectedDate, now) && now.hour == hour;

        return IntrinsicHeight(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hour label ──
                ScheduleHourLabel(
                    timeLabel: timeLabel, isCurrentHour: isCurrentHour),

                // ── Timeline line + indicators ──
                ScheduleHourMarker(
                    isCurrentHour: isCurrentHour, isShiftHour: isShiftHour),

                // ── Content area (shift card or availability indicator) ──
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.only(
                      right: AppSpacing.md, bottom: AppSpacing.sm),
                  child: startingShift.isNotEmpty
                      ? ScheduleShiftCard(shift: startingShift.first)
                      : const SizedBox.shrink(),
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}
