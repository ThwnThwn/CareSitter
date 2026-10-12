String formatDate(DateTime date,
    {bool padded = false, bool includeYear = true}) {
  String number(int n) => padded ? n.toString().padLeft(2, '0') : n.toString();
  return '${number(date.day)}/${number(date.month)}${includeYear ? '/${padded ? date.year.toString().padLeft(4, '0') : date.year}' : ''}';
}

String formatClock(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String formatDuration(Duration value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.inHours)}:${two(value.inMinutes % 60)}:${two(value.inSeconds % 60)}';
}
