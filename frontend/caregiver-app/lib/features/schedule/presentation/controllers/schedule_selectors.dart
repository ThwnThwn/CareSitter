import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/schedule/data/models/schedule_slot_model.dart';
import 'package:caregiver_app/features/schedule/domain/schedule_rules.dart';
import 'package:caregiver_app/features/schedule/presentation/controllers/schedule_controller.dart';

final daySlotsProvider =
    Provider.autoDispose.family<List<AvailabilitySlot>, DateTime>((ref, date) {
  final slots = ref.watch(scheduleProvider);
  return slots
      .where((slot) => ScheduleRules.matchesDate(slot.date, '', date))
      .toList()
    ..sort((a, b) => a.startHour.compareTo(b.startHour));
});

final dayShiftsProvider =
    Provider.autoDispose.family<List<TimelineShift>, DateTime>((ref, date) {
  final shifts = ref.watch(shiftsProvider);
  return [
    for (final shift in shifts)
      if (ScheduleRules.matchesDate(shift.scheduledStart, shift.date, date) &&
          ScheduleRules.canShow(shift.status))
        if (ScheduleRules.hours(shift.time) case final hours?)
          TimelineShift(
              id: shift.id,
              beneficiaryName: shift.beneficiaryName,
              serviceName: shift.serviceName,
              status: shift.status,
              startHour: hours.start,
              endHour: hours.end,
              duration: shift.duration,
              address: shift.address)
  ];
});
