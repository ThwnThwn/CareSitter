import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/schedule/domain/schedule_rules.dart';

final dayShiftsProvider =
    Provider.autoDispose.family<List<TimelineShift>, DateTime>((ref, date) {
  final shifts = ref.watch(shiftsProvider);
  return [
    for (final shift in shifts)
      if (ScheduleRules.matchesDate(shift.scheduledStart, '', date) &&
          ScheduleRules.canShow(shift.status))
        if (shift.scheduledStart != null && shift.scheduledEnd != null)
          TimelineShift(
              id: shift.id,
              beneficiaryName: shift.beneficiaryName,
              serviceName: shift.serviceName,
              status: shift.status,
              startHour: shift.scheduledStart!.hour,
              endHour: shift.scheduledEnd!.hour,
              duration: shift.duration,
              address: shift.address)
  ];
});
