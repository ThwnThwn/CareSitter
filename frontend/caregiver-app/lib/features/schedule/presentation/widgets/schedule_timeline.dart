import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:caregiver_app/core/theme/app_spacing.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_hour_marker.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_hour_label.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_hour_content.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/schedule/data/models/schedule_slot_model.dart';

class ScheduleTimeline extends StatelessWidget {
  const ScheduleTimeline(
      {super.key,
      required this.timelineScrollController,
      required this.daySlots,
      required this.dayShifts,
      required this.isToday,
      required this.selectedDate,
      required this.buildShiftCard,
      required this.isSlotStart,
      required this.buildAvailabilityIndicator});
  final ScrollController timelineScrollController;
  final List<AvailabilitySlot> daySlots;
  final List<TimelineShift> dayShifts;
  final bool Function(DateTime) isToday;
  final DateTime selectedDate;
  final Widget Function(TimelineShift) buildShiftCard;
  final bool Function(List<AvailabilitySlot>, int) isSlotStart;
  final Widget Function(AvailabilitySlot, BuildContext)
      buildAvailabilityIndicator;
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

        // Check if this hour falls within an availability slot
        final matchingSlot =
            daySlots.where((s) => hour >= s.startHour && hour < s.endHour);
        final isAvailable = matchingSlot.isNotEmpty;

        // Check if there's a shift starting at this hour
        final startingShift =
            dayShifts.where((s) => s.startHour == hour).toList();

        // Check if this hour is covered by a shift (for the green bar)
        final isShiftHour =
            dayShifts.any((s) => hour >= s.startHour && hour < s.endHour);

        // Current hour indicator
        final now = DateTime.now();
        final isCurrentHour = isToday(selectedDate) && now.hour == hour;

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
                    isCurrentHour: isCurrentHour,
                    isShiftHour: isShiftHour,
                    isAvailable: isAvailable),

                // ── Content area (shift card or availability indicator) ──
                ScheduleHourContent(
                    startingShift: startingShift,
                    buildShiftCard: buildShiftCard,
                    isAvailable: isAvailable,
                    isSlotStart: isSlotStart,
                    daySlots: daySlots,
                    hour: hour,
                    buildAvailabilityIndicator: buildAvailabilityIndicator,
                    matchingSlot: matchingSlot),
              ],
            ),
          ),
        );
      },
    );
  }
}
