import '../../data/models/schedule_slot_model.dart';

extension AvailabilityDisplay on AvailabilitySlot {
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
