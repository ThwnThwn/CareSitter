import 'package:caregiver_app/core/utils/date_formatter.dart';
import '../../data/models/shift_model.dart';

extension ShiftDisplayModel on ShiftModel {
  String get date => scheduledStart == null
      ? 'Chưa có ngày'
      : formatDate(scheduledStart!, padded: true);
  String get time => scheduledStart == null || scheduledEnd == null
      ? 'Chưa có giờ'
      : '${formatClock(scheduledStart!)} - ${formatClock(scheduledEnd!)}';
  String get duration => scheduledStart == null || scheduledEnd == null
      ? 'Chưa có thời lượng'
      : '${scheduledEnd!.difference(scheduledStart!).inHours} giờ';
}
