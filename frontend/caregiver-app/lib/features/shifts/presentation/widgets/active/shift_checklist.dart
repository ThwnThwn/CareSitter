import 'package:caregiver_app/features/shifts/presentation/controllers/shift_action_policy.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_selectors.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_row.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_editor.dart';

class ShiftChecklist extends ConsumerWidget {
  const ShiftChecklist({super.key, required this.booking});
  final ShiftModel booking;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(activeShiftSummaryProvider(booking.id));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text('Checklist công việc',
                style: Theme.of(context).textTheme.titleLarge)),
        Text('${summary.completed} / ${summary.total}')
      ]),
      if (!booking.canWorkChecklist)
        const Text('Checklist sẽ mở sau khi bạn check-in.'),
      if (summary.skipped > 0) Text('${summary.skipped} việc không thực hiện được'),
      const SizedBox(height: AppSpacing.compact),
      if (booking.tasks.isEmpty)
        const Text('Không có checklist công việc đặc biệt.'),
      for (final task in booking.tasks)
        ShiftTaskRow(key: ValueKey(task.id), booking: booking, task: task),
      if (booking.canWorkChecklist && booking.allowAdHocTasks)
        OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm việc phát sinh'),
            onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ShiftTaskEditor(
                    bookingId: booking.id, mode: ShiftTaskEditorMode.create))),
    ]);
  }
}
