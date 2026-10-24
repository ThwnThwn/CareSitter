class ScheduleRules {
  static bool matchesDate(DateTime? start, String fallback, DateTime date) {
    if (start != null) {
      return start.year == date.year &&
          start.month == date.month &&
          start.day == date.day;
    }
    final parts = fallback.split('/');
    return parts.length == 3 &&
        int.tryParse(parts[0]) == date.day &&
        int.tryParse(parts[1]) == date.month &&
        int.tryParse(parts[2]) == date.year;
  }

  static bool canShow(String status) => const {
        'confirmed',
        'assigned',
        'in_progress',
        'caregiver_en_route',
        'pending'
      }.contains(status);

  static ({int start, int end})? hours(String time) {
    final parts = time.split(' - ');
    if (parts.length != 2) return null;
    return (
      start: int.tryParse(parts[0].split(':')[0]) ?? 0,
      end: int.tryParse(parts[1].split(':')[0]) ?? 0
    );
  }

  /// Converts an absolute booking interval into hour rows for its start day.
  /// Midnight on the following day is represented by 24 so the final rows of
  /// an overnight shift remain highlighted on the timeline.
  static ({int start, int end})? timelineHours(
    DateTime start,
    DateTime end,
  ) {
    final minutes = timelineMinutes(start, end);
    if (minutes == null) return null;

    final startHour = minutes.start ~/ 60;
    final endHour = (minutes.end + 59) ~/ 60;
    return (start: startHour, end: endHour);
  }

  /// Converts a booking interval to exact minute offsets on its start day.
  /// Overnight shifts continue beyond 1440 (24:00) so their full duration can
  /// remain visible below the final hour of the selected day.
  static ({int start, int end})? timelineMinutes(
    DateTime start,
    DateTime end,
  ) {
    if (!end.isAfter(start)) return null;

    final startMinute = start.hour * 60 + start.minute;
    final endsOnStartDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (!endsOnStartDay) {
      final startOfDay = DateTime(start.year, start.month, start.day);
      return (start: startMinute, end: end.difference(startOfDay).inMinutes);
    }

    final endMinute = end.hour * 60 + end.minute;
    return (start: startMinute, end: endMinute);
  }
}
