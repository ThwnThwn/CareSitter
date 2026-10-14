import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_task_identity.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_task_skip_reason.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_task_photos.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_task_completion_time.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTaskRowContent extends StatelessWidget {
  const ShiftTaskRowContent(
      {super.key,
      required this.isDone,
      required this.isSkipped,
      required this.task});
  final bool isDone;
  final bool isSkipped;
  final CareTaskModel task;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShiftTaskIdentity(isDone: isDone, isSkipped: isSkipped, task: task),
          // Skip reason banner
          if (isSkipped &&
              task.skipReason != null &&
              task.skipReason!.isNotEmpty)
            ShiftTaskSkipReason(task: task),
          // Photos gallery
          if (task.photoUrls.isNotEmpty) ShiftTaskPhotos(task: task),
          // Completion timestamp
          if (isDone && task.completedAt != null)
            ShiftTaskCompletionTime(task: task),
        ],
      );
}
