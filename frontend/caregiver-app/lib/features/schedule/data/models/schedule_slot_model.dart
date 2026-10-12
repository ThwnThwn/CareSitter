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

}
