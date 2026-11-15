class BookingMealCorrectionModel {
  const BookingMealCorrectionModel(
      {required this.id,
      required this.revision,
      required this.outcome,
      required this.reason,
      required this.correctedBy,
      required this.correctedAt,
      required this.timelineEventId,
      this.note});
  final String id, outcome, reason, correctedBy, timelineEventId;
  final int revision;
  final String? note;
  final DateTime correctedAt;
  factory BookingMealCorrectionModel.fromJson(Map<String, dynamic> json) =>
      BookingMealCorrectionModel(
          id: json['id'] as String,
          revision: (json['revision'] as num).toInt(),
          outcome: json['outcome'] as String,
          note: json['note'] as String?,
          reason: json['reason'] as String,
          correctedBy: json['correctedBy'] as String,
          correctedAt: DateTime.parse(json['correctedAt'] as String),
          timelineEventId: json['timelineEventId'] as String);
}
