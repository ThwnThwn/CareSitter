/// Ca đã được đặt, dùng để hiển thị trên timeline lịch làm việc.
class TimelineShift {
  final String id;
  final String beneficiaryName;
  final String serviceName;
  final String status;
  final int startHour;
  final int endHour;
  final int? startMinute;
  final int? endMinute;
  final String duration;
  final String address;
  final double? addressLatitude;
  final double? addressLongitude;
  final int? beneficiaryAge;
  final String? beneficiaryGender;
  final String? beneficiaryAvatarUrl;
  final String? beneficiaryCondition;
  final DateTime? scheduledStart;
  final List<String> taskTitles;

  const TimelineShift({
    required this.id,
    required this.beneficiaryName,
    required this.serviceName,
    required this.status,
    required this.startHour,
    required this.endHour,
    this.startMinute,
    this.endMinute,
    required this.duration,
    required this.address,
    this.addressLatitude,
    this.addressLongitude,
    this.beneficiaryAge,
    this.beneficiaryGender,
    this.beneficiaryAvatarUrl,
    this.beneficiaryCondition,
    this.scheduledStart,
    this.taskTitles = const [],
  });

  int get timelineStartMinute => startMinute ?? startHour * 60;
  int get timelineEndMinute => endMinute ?? endHour * 60;

  String get timeRangeLabel =>
      '${formatMinute(timelineStartMinute)} – ${formatMinute(timelineEndMinute)}';

  int get durationMinutes => timelineEndMinute - timelineStartMinute;

  static String formatMinute(int minute) {
    final hour = (minute ~/ 60) % 24;
    final remainder = minute % 60;
    return '${hour.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}
