String formatDate(DateTime date, {bool padded = false, bool includeYear = true}) {
  String number(int n) => padded ? n.toString().padLeft(2, '0') : n.toString();
  return '${number(date.day)}/${number(date.month)}${includeYear ? '/${padded ? date.year.toString().padLeft(4, '0') : date.year}' : ''}';
}

String formatClock(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String formatDuration(Duration value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.inHours)}:${two(value.inMinutes % 60)}:${two(value.inSeconds % 60)}';
}

String formatRelativeTime(DateTime? value, {DateTime? now}) {
  if (value == null) return 'Chưa có thời gian';
  final diff = (now ?? DateTime.now()).difference(value);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return formatDate(value.toLocal());
}
