class ScheduleRules {
  const ScheduleRules._();
  static const minimumDurationHours = 2;
  static const maximumDurationHours = 12;
  static DateTime at(DateTime date, int minutes) =>
      DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
  static DateTime snap(DateTime date, int minutes) =>
      at(date, ((minutes + 2) ~/ 5) * 5);
  static bool isValid(DateTime? date, int? minutes, DateTime now) =>
      date != null &&
      minutes != null &&
      at(date, minutes).isAfter(now.add(const Duration(minutes: 30)));
}
