import 'package:caregiver_app/core/utils/date_formatter.dart';
import '../../data/models/shift_model.dart';

extension ShiftDisplayModel on ShiftModel {
  String get date => scheduledStart == null
      ? 'Chưa có ngày'
      : formatDate(scheduledStart!, padded: true);
  String get time => scheduledStart == null || scheduledEnd == null
      ? 'Chưa có giờ'
      : '${formatClock(scheduledStart!)} - ${formatClock(scheduledEnd!)}';
  String get duration {
    if (scheduledStart == null || scheduledEnd == null) return 'Chưa có thời lượng';
    final diff = scheduledEnd!.difference(scheduledStart!);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours == 0) return '$minutes phút';
    if (minutes == 0) return '$hours tiếng';
    return '$hours tiếng $minutes phút';
  }
}
