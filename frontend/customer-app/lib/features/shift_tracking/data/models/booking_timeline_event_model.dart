class BookingTimelineEventModel {
  const BookingTimelineEventModel(
      {required this.id,
      required this.eventType,
      required this.title,
      required this.note,
      required this.recordedAt});
  final String id, eventType;
  final String? title, note;
  final DateTime recordedAt;
  factory BookingTimelineEventModel.fromJson(Map<String, dynamic> json) =>
      BookingTimelineEventModel(
          id: json['id'] as String,
          eventType: json['eventType'] as String,
          title: json['title'] as String?,
          note: json['note'] as String?,
          recordedAt: DateTime.parse(json['recordedAt'] as String));
}
