import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_notifier.dart';

/// Represents a single availability time slot.
class AvailabilitySlot {
  final String id;
  final DateTime date;
  final int startHour; // 0-23
  final int endHour; // 1-24
  final bool isBooked; // true if a shift occupies this slot

  const AvailabilitySlot({
    required this.id,
    required this.date,
    required this.startHour,
    required this.endHour,
    this.isBooked = false,
  });

  AvailabilitySlot copyWith({
    DateTime? date,
    int? startHour,
    int? endHour,
    bool? isBooked,
  }) {
    return AvailabilitySlot(
      id: id,
      date: date ?? this.date,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      isBooked: isBooked ?? this.isBooked,
    );
  }

  String get timeLabel {
    final startStr = '${startHour.toString().padLeft(2, '0')}:00';
    final endStr = '${endHour.toString().padLeft(2, '0')}:00';
    return '$startStr - $endStr';
  }

  String get periodLabel {
    if (startHour < 12) return 'Sáng';
    if (startHour < 18) return 'Chiều';
    return 'Tối';
  }
}

/// Represents a booked shift to display on the timeline.
class TimelineShift {
  final String id;
  final String beneficiaryName;
  final String serviceName;
  final String status;
  final int startHour;
  final int endHour;
  final String duration;
  final String address;

  const TimelineShift({
    required this.id,
    required this.beneficiaryName,
    required this.serviceName,
    required this.status,
    required this.startHour,
    required this.endHour,
    required this.duration,
    required this.address,
  });
}

class ScheduleNotifier extends StateNotifier<List<AvailabilitySlot>> {
  final Ref _ref;

  ScheduleNotifier(this._ref) : super([]) {
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
    return state.where((s) {
      final slotDate = DateTime(s.date.year, s.date.month, s.date.day);
      return slotDate == target;
    }).toList()
      ..sort((a, b) => a.startHour.compareTo(b.startHour));
  }

  Future<void> addSlot(DateTime date, int startHour, int endHour) async {
    // Availability không còn là dữ liệu được lưu trong hệ thống.
    return;
  }

  Future<void> removeSlot(String id) async {
    return;
  }

  bool hasSlotAt(DateTime date, int hour) {
    final target = DateTime(date.year, date.month, date.day);
    return state.any((s) {
      final slotDate = DateTime(s.date.year, s.date.month, s.date.day);
      return slotDate == target && hour >= s.startHour && hour < s.endHour;
    });
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, List<AvailabilitySlot>>((ref) {
  return ScheduleNotifier(ref);
});
