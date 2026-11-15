import 'booking_meal_correction_model.dart';

class BookingMealRecordModel {
  const BookingMealRecordModel(
      {required this.id,
      required this.planId,
      required this.plannedDate,
      required this.recipeVersionId,
      required this.mealType,
      required this.outcome,
      required this.recordedBy,
      required this.recordedAt,
      required this.timelineEventId,
      this.note,
      this.revision = 1,
      this.corrections = const [],
      this.originalOutcome,
      this.originalNote});
  final String id,
      planId,
      plannedDate,
      recipeVersionId,
      mealType,
      outcome,
      recordedBy,
      timelineEventId;
  final String? note, originalOutcome, originalNote;
  final int revision;
  final List<BookingMealCorrectionModel> corrections;
  final DateTime recordedAt;
  factory BookingMealRecordModel.fromJson(Map<String, dynamic> json) =>
      BookingMealRecordModel(
          revision: (json['revision'] as num?)?.toInt() ?? 1,
          corrections: (json['corrections'] as List<dynamic>? ?? const [])
              .map((x) => BookingMealCorrectionModel.fromJson(
                  x as Map<String, dynamic>))
              .toList(growable: false),
          originalOutcome: json['originalOutcome'] as String?,
          originalNote: json['originalNote'] as String?,
          id: json['id'] as String,
          planId: json['planId'] as String,
          plannedDate: json['plannedDate'] as String,
          recipeVersionId: json['recipeVersionId'] as String,
          mealType: json['mealType'] as String,
          outcome: json['outcome'] as String,
          note: json['note'] as String?,
          recordedBy: json['recordedBy'] as String,
          recordedAt: DateTime.parse(json['recordedAt'] as String),
          timelineEventId: json['timelineEventId'] as String);
}
