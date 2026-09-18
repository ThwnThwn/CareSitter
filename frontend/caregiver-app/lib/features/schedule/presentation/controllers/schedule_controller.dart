import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/schedule/data/models/schedule_slot_model.dart';

class ScheduleController extends StateNotifier<List<AvailabilitySlot>> {
  final Ref _ref;

  ScheduleController(this._ref) : super([]) {
    _ref.listen(authStateProvider, (previous, next) {
      if (next.value?.isAuthenticated ?? false) {
        refresh();
      } else {
        state = [];
      }
    });
    refresh();
  }

  Future<void> refresh() async {
    // Availability API/table đã được gỡ. Lịch caregiver hiện chỉ hiển thị
    // các booking thật lấy từ shiftsProvider, không gọi endpoint cũ 404.
    state = [];
  }

  List<AvailabilitySlot> getSlotsForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return state.where((slot) {
      final slotDate = DateTime(slot.date.year, slot.date.month, slot.date.day);
      return slotDate == target;
    }).toList()
      ..sort((a, b) => a.startHour.compareTo(b.startHour));
  }

  Future<void> addSlot(DateTime date, int startHour, int endHour) async {
    // Availability không còn là dữ liệu được lưu trong hệ thống.
  }

  Future<void> removeSlot(String id) async {
    // Availability không còn là dữ liệu được lưu trong hệ thống.
  }

  bool hasSlotAt(DateTime date, int hour) {
    final target = DateTime(date.year, date.month, date.day);
    return state.any((slot) {
      final slotDate = DateTime(slot.date.year, slot.date.month, slot.date.day);
      return slotDate == target &&
          hour >= slot.startHour &&
          hour < slot.endHour;
    });
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleController, List<AvailabilitySlot>>((ref) {
  return ScheduleController(ref);
});
