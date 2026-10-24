import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/schedule/domain/schedule_rules.dart';

final dayShiftsProvider =
    Provider.autoDispose.family<List<TimelineShift>, DateTime>((ref, date) {
  final shifts = ref.watch(shiftsProvider);
  final timelineShifts = <TimelineShift>[];

  for (final shift in shifts) {
    final start = shift.scheduledStart;
    final end = shift.scheduledEnd;
    if (start == null ||
        end == null ||
        !ScheduleRules.matchesDate(start, '', date) ||
        !ScheduleRules.canShow(shift.status)) {
      continue;
    }

    final hours = ScheduleRules.timelineHours(start, end);
    final minutes = ScheduleRules.timelineMinutes(start, end);
    if (hours == null || minutes == null) continue;

    timelineShifts.add(TimelineShift(
        id: shift.id,
        beneficiaryName: shift.beneficiaryName,
        serviceName: shift.serviceName,
        status: shift.status,
        startHour: hours.start,
        endHour: hours.end,
        startMinute: minutes.start,
        endMinute: minutes.end,
        duration: shift.duration,
        address: shift.address,
        addressLatitude: shift.addressLatitude,
        addressLongitude: shift.addressLongitude,
        beneficiaryAge: shift.beneficiaryAge,
        beneficiaryGender: shift.beneficiaryGender,
        beneficiaryAvatarUrl: shift.beneficiaryAvatarUrl,
        beneficiaryCondition: shift.beneficiaryCondition,
        scheduledStart: shift.scheduledStart,
        taskTitles: shift.tasks
            .map((task) => task.title.trim())
            .where((title) => title.isNotEmpty)
            .take(2)
            .toList(growable: false)));
  }

  timelineShifts.sort(
    (left, right) =>
        left.timelineStartMinute.compareTo(right.timelineStartMinute),
  );
  return timelineShifts;
});
