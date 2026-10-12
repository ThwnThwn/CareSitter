import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/schedule/data/models/schedule_slot_model.dart';

class ScheduleContent extends StatelessWidget {
  const ScheduleContent(
      {super.key,
      required this.buildHeader,
      required this.buildDateSelector,
      required this.buildTimeline,
      required this.daySlots,
      required this.dayShifts});
  final Widget Function() buildHeader;
  final Widget Function() buildDateSelector;
  final Widget Function(List<AvailabilitySlot>, List<TimelineShift>)
      buildTimeline;
  final List<AvailabilitySlot> daySlots;
  final List<TimelineShift> dayShifts;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          // ── Top Header with month, day, and nav ──
          buildHeader(),
          // ── Date Selector Row ──
          buildDateSelector(),
          const SizedBox(height: AppSpacing.xs),
          // ── Timeline Body ──
          Expanded(
            child: buildTimeline(daySlots, dayShifts),
          ),
        ],
      );
}
