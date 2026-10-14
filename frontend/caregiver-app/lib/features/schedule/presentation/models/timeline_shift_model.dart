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
