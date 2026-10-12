import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/schedule/data/models/schedule_slot_model.dart';

class ScheduleHourContent extends StatelessWidget {
  const ScheduleHourContent(
      {super.key,
      required this.startingShift,
      required this.buildShiftCard,
      required this.isAvailable,
      required this.isSlotStart,
      required this.daySlots,
      required this.hour,
      required this.buildAvailabilityIndicator,
      required this.matchingSlot});
  final List<TimelineShift> startingShift;
  final Widget Function(TimelineShift) buildShiftCard;
  final bool isAvailable;
  final bool Function(List<AvailabilitySlot>, int) isSlotStart;
  final List<AvailabilitySlot> daySlots;
  final int hour;
  final Widget Function(AvailabilitySlot, BuildContext)
      buildAvailabilityIndicator;
  final Iterable<AvailabilitySlot> matchingSlot;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(
              right: AppSpacing.md, bottom: AppSpacing.sm),
          child: startingShift.isNotEmpty
              ? buildShiftCard(startingShift.first)
              : isAvailable && isSlotStart(daySlots, hour)
                  ? buildAvailabilityIndicator(matchingSlot.first, context)
                  : const SizedBox.shrink(),
        ),
      );
}
