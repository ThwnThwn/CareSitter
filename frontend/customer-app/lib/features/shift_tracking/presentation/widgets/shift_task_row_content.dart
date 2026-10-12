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
      required this.iconForTask,
      required this.task,
      required this.showPhotoPreviewDialog});
  final bool isDone;
  final bool isSkipped;
  final IconData Function(String) iconForTask;
  final CareTaskModel task;
  final void Function(BuildContext, String) showPhotoPreviewDialog;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShiftTaskIdentity(
              isDone: isDone,
              isSkipped: isSkipped,
              iconForTask: iconForTask,
              task: task),
          // Skip reason banner
          if (isSkipped &&
              task.skipReason != null &&
              task.skipReason!.isNotEmpty)
            ShiftTaskSkipReason(task: task),
          // Photos gallery
          if (task.photoUrls.isNotEmpty)
            ShiftTaskPhotos(
                task: task, showPhotoPreviewDialog: showPhotoPreviewDialog),
          // Completion timestamp
          if (isDone && task.completedAt != null)
            ShiftTaskCompletionTime(task: task),
        ],
      );
}
