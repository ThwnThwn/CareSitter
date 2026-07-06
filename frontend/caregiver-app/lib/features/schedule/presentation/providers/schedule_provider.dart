import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents a single availability time slot
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

/// Represents a booked shift to display on the timeline
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
  ScheduleNotifier() : super([]) {
    _init();
  }

  int _nextId = 10;

  void _init() {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final dayAfter = today.add(const Duration(days: 2));

    state = [
      // Today's available slots
      AvailabilitySlot(
        id: 'avl_01',
        date: DateTime(today.year, today.month, today.day),
        startHour: 7,
        endHour: 12,
      ),
      AvailabilitySlot(
        id: 'avl_02',
        date: DateTime(today.year, today.month, today.day),
        startHour: 14,
        endHour: 17,
      ),
      AvailabilitySlot(
        id: 'avl_03',
        date: DateTime(today.year, today.month, today.day),
        startHour: 19,
        endHour: 22,
      ),
      // Tomorrow's available slots
      AvailabilitySlot(
        id: 'avl_04',
        date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        startHour: 8,
        endHour: 11,
      ),
      AvailabilitySlot(
        id: 'avl_05',
        date: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
        startHour: 13,
        endHour: 18,
      ),
      // Day after tomorrow
      AvailabilitySlot(
        id: 'avl_06',
        date: DateTime(dayAfter.year, dayAfter.month, dayAfter.day),
        startHour: 7,
        endHour: 19,
      ),
    ];
  }

  List<AvailabilitySlot> getSlotsForDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return state.where((s) {
      final slotDate = DateTime(s.date.year, s.date.month, s.date.day);
      return slotDate == target;
    }).toList()
      ..sort((a, b) => a.startHour.compareTo(b.startHour));
  }

  void addSlot(DateTime date, int startHour, int endHour) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final newSlot = AvailabilitySlot(
      id: 'avl_${_nextId++}',
      date: normalizedDate,
      startHour: startHour,
      endHour: endHour,
    );
    state = [...state, newSlot];
  }

  void removeSlot(String id) {
    state = state.where((s) => s.id != id).toList();
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
  return ScheduleNotifier();
});
