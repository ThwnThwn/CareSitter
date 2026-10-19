class BookingChatTemplate {
  const BookingChatTemplate({
    required this.key,
    required this.version,
    required this.body,
    this.allowedMinutes,
  });

  final String key;
  final int version;
  final String body;
  final List<int>? allowedMinutes;
}
