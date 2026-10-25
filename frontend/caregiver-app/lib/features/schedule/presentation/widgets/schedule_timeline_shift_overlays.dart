import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/theme/shift_status_style.dart';
import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_shift_card.dart';
import 'package:flutter/material.dart';

class ScheduleTimelineShiftTime extends StatelessWidget {
  const ScheduleTimelineShiftTime({
    super.key,
    required this.shift,
    required this.hourExtent,
    required this.hourLabelWidth,
  });

  final TimelineShift shift;
  final double hourExtent;
  final double hourLabelWidth;

  @override
  Widget build(BuildContext context) {
    final top = shift.timelineStartMinute / 60 * hourExtent;
    final color = ShiftStatusStyle.of(shift.status).color;
    return Positioned(
      top: top + AppSpacing.xs,
      left: 0,
      width: hourLabelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            TimelineShift.formatMinute(shift.timelineStartMinute),
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: AppFontSizes.s11,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.micro),
          Text(
            TimelineShift.formatMinute(shift.timelineEndMinute),
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              fontSize: AppFontSizes.s9,
              height: 1.15,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleTimelineShiftPosition extends StatelessWidget {
  const ScheduleTimelineShiftPosition({
    super.key,
    required this.shift,
    required this.hourExtent,
    required this.hourLabelWidth,
    required this.railWidth,
    required this.contentGap,
    required this.hourMarkerOffset,
  });

  final TimelineShift shift;
  final double hourExtent;
  final double hourLabelWidth;
  final double railWidth;
  final double contentGap;
  final double hourMarkerOffset;

  @override
  Widget build(BuildContext context) {
    final start = shift.timelineStartMinute.clamp(0, 30 * 60).toInt();
    final end = shift.timelineEndMinute.clamp(start + 1, 30 * 60).toInt();
    final top = start / 60 * hourExtent;
    final railHeight = ((end - start) / 60 * hourExtent + hourMarkerOffset)
        .clamp(44.0, double.infinity)
        .toDouble();
    final layoutHeight = railHeight < 216 ? 216.0 : railHeight;
    final statusColor = ShiftStatusStyle.of(shift.status).color;

    return Positioned(
      top: top,
      left: hourLabelWidth,
      right: AppSpacing.md,
      height: layoutHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShiftDurationRail(
            shiftId: shift.id,
            width: railWidth,
            height: railHeight,
            markerOffset: hourMarkerOffset,
            color: statusColor,
          ),
          SizedBox(width: contentGap),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Align(
                alignment: Alignment.topLeft,
                child: ScheduleShiftCard(shift: shift),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftDurationRail extends StatelessWidget {
  const _ShiftDurationRail({
    required this.shiftId,
    required this.width,
    required this.height,
    required this.markerOffset,
    required this.color,
  });

  final String shiftId;
  final double width;
  final double height;
  final double markerOffset;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: markerOffset,
              bottom: 0,
              child: Container(
                key: ValueKey('schedule-duration-rail-$shiftId'),
                width: 3,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            _RailDot(color: color, top: 2.5),
            Positioned(
              bottom: -5.5,
              child: _RailDot(
                key: ValueKey('schedule-duration-end-dot-$shiftId'),
                color: color,
              ),
            ),
          ],
        ),
      );
}

class _RailDot extends StatelessWidget {
  const _RailDot({super.key, required this.color, this.top});

  final Color color;
  final double? top;

  @override
  Widget build(BuildContext context) => Container(
        width: 11,
        height: 11,
        margin: top == null ? null : EdgeInsets.only(top: top!),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.background, width: 2),
        ),
      );
}
