/// Một khoảng thời gian caregiver có thể nhận ca.
class AvailabilitySlot {
  final String id;
  final DateTime date;
  final int startHour;
  final int endHour;
  final bool isBooked;

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

/// Ca đã được đặt, dùng để hiển thị trên timeline lịch làm việc.
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
