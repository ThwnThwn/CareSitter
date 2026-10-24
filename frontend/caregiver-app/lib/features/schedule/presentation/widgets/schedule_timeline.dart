import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/theme/shift_status_style.dart';
import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_shift_card.dart';
import 'package:flutter/material.dart';

class ScheduleTimeline extends StatelessWidget {
  const ScheduleTimeline({
    super.key,
    required this.timelineScrollController,
    required this.dayShifts,
    required this.selectedDate,
  });

  static const double hourExtent = 104;
  static const double _hourLabelWidth = 58;
  static const double _railWidth = 20;
  static const double _contentGap = 6;
  static const double _bottomPadding = 112;
  static const double _hourMarkerOffset = AppSpacing.sm;

  final ScrollController timelineScrollController;
  final List<TimelineShift> dayShifts;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final shifts = List<TimelineShift>.of(dayShifts)
      ..sort((left, right) =>
          left.timelineStartMinute.compareTo(right.timelineStartMinute));
    final latestMinute = shifts.fold<int>(
      24 * 60,
      (latest, shift) =>
          shift.timelineEndMinute > latest ? shift.timelineEndMinute : latest,
    );
    final hourCount = ((latestMinute + 59) ~/ 60).clamp(24, 30);
    final timelineHeight = hourCount * hourExtent;

    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: SingleChildScrollView(
        controller: timelineScrollController,
        padding: const EdgeInsets.only(bottom: _bottomPadding),
        child: SizedBox(
          height: timelineHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: _TimelineGrid(
                  hourCount: hourCount,
                  hiddenHourLabels: {
                    for (final shift in shifts)
                      if (shift.timelineStartMinute % 60 == 0)
                        shift.timelineStartMinute ~/ 60,
                  },
                ),
              ),
              for (final shift in shifts) _TimelineShiftTime(shift: shift),
              for (final shift in shifts) _TimelineShiftPosition(shift: shift),
              for (var index = 0; index < shifts.length - 1; index++)
                _TimelineBreakMarker(
                  startMinute: shifts[index].timelineEndMinute,
                  endMinute: shifts[index + 1].timelineStartMinute,
                ),
              if (shifts.isEmpty)
                const Positioned(
                  top: hourExtent * 2,
                  left: _hourLabelWidth + _railWidth + _contentGap,
                  right: AppSpacing.md,
                  child: _EmptyScheduleState(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineShiftTime extends StatelessWidget {
  const _TimelineShiftTime({required this.shift});

  final TimelineShift shift;

  @override
  Widget build(BuildContext context) {
    final top = shift.timelineStartMinute / 60 * ScheduleTimeline.hourExtent;
    final color = ShiftStatusStyle.of(shift.status).color;
    return Positioned(
      top: top + AppSpacing.xs,
      left: 0,
      width: ScheduleTimeline._hourLabelWidth,
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

class _TimelineGrid extends StatelessWidget {
  const _TimelineGrid({
    required this.hourCount,
    required this.hiddenHourLabels,
  });

  final int hourCount;
  final Set<int> hiddenHourLabels;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: ScheduleTimeline._hourLabelWidth +
                ScheduleTimeline._railWidth / 2,
            child: Container(
              width: 1,
              color: AppColors.border.withValues(alpha: 0.72),
            ),
          ),
          for (var hour = 0; hour < hourCount; hour++)
            Positioned(
              top: hour * ScheduleTimeline.hourExtent,
              left: 0,
              right: 0,
              height: ScheduleTimeline.hourExtent,
              child: _TimelineHour(
                hour: hour,
                hideLabel: hiddenHourLabels.contains(hour),
              ),
            ),
        ],
      );
}

class _TimelineHour extends StatelessWidget {
  const _TimelineHour({required this.hour, required this.hideLabel});

  final int hour;
  final bool hideLabel;

  @override
  Widget build(BuildContext context) => Row(
        key: ValueKey('schedule-hour-$hour'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ScheduleTimeline._hourLabelWidth,
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                right: AppSpacing.micro,
                top: AppSpacing.xs,
              ),
              child: hideLabel
                  ? const SizedBox.shrink()
                  : Text(
                      '${(hour % 24).toString().padLeft(2, '0')}:00',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: AppFontSizes.s12,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),
          SizedBox(
            width: ScheduleTimeline._railWidth,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.5),
                child: Container(
                  key: ValueKey('schedule-hour-dot-$hour'),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.border,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Divider(
                color: AppColors.border.withValues(alpha: 0.55),
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      );
}

class _TimelineShiftPosition extends StatelessWidget {
  const _TimelineShiftPosition({required this.shift});

  final TimelineShift shift;

  @override
  Widget build(BuildContext context) {
    final start = shift.timelineStartMinute.clamp(0, 30 * 60).toInt();
    final end = shift.timelineEndMinute.clamp(start + 1, 30 * 60).toInt();
    final top = start / 60 * ScheduleTimeline.hourExtent;
    final railHeight = ((end - start) / 60 * ScheduleTimeline.hourExtent +
            ScheduleTimeline._hourMarkerOffset)
        .clamp(44.0, double.infinity)
        .toDouble();
    final layoutHeight = railHeight < 216 ? 216.0 : railHeight;
    final statusColor = ShiftStatusStyle.of(shift.status).color;

    return Positioned(
      top: top,
      left: ScheduleTimeline._hourLabelWidth,
      right: AppSpacing.md,
      height: layoutHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ScheduleTimeline._railWidth,
            height: railHeight,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: ScheduleTimeline._hourMarkerOffset,
                  bottom: 0,
                  child: Container(
                    key: ValueKey('schedule-duration-rail-${shift.id}'),
                    width: 3,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(top: 2.5),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.background,
                      width: 2,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -5.5,
                  child: Container(
                    key: ValueKey(
                      'schedule-duration-end-dot-${shift.id}',
                    ),
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.background,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ScheduleTimeline._contentGap),
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

class _TimelineBreakMarker extends StatelessWidget {
  const _TimelineBreakMarker({
    required this.startMinute,
    required this.endMinute,
  });

  final int startMinute;
  final int endMinute;

  @override
  Widget build(BuildContext context) {
    if (endMinute - startMinute < 60) return const SizedBox.shrink();

    final top =
        startMinute / 60 * ScheduleTimeline.hourExtent + AppSpacing.compact;
    return Positioned(
      top: top,
      left: ScheduleTimeline._hourLabelWidth +
          ScheduleTimeline._railWidth +
          ScheduleTimeline._contentGap,
      right: AppSpacing.md,
      child: Text(
        'Khoảng nghỉ: ${TimelineShift.formatMinute(startMinute)} – '
        '${TimelineShift.formatMinute(endMinute)}',
        style: const TextStyle(
          fontSize: AppFontSizes.s11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyScheduleState extends StatelessWidget {
  const _EmptyScheduleState();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 34,
              color: AppColors.primary,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Không có ca làm việc',
              style: TextStyle(
                fontSize: AppFontSizes.s15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Bạn đang rảnh trong ngày này.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSizes.s12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
}
