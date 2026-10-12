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
}
