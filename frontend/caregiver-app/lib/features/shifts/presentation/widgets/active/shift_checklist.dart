import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_action_policy.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_selectors.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_editor.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_task_row.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_checklist_header.dart';

class ShiftChecklist extends ConsumerWidget {
  const ShiftChecklist({super.key, required this.booking});

  final ShiftModel booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(activeShiftSummaryProvider(booking.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShiftChecklistHeader(
          completed: summary.completed,
          total: summary.total,
        ),
        if (summary.skipped > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('${summary.skipped} việc không thực hiện được'),
        ],
        const SizedBox(height: AppSpacing.compact),
        if (booking.tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('Không có checklist công việc đặc biệt.'),
          )
        else
          for (final task in booking.tasks) ...[
            ShiftTaskRow(
              key: ValueKey(task.id),
              booking: booking,
              task: task,
            ),
            const SizedBox(height: AppSpacing.compact),
          ],
        if (booking.canWorkChecklist && booking.allowAdHocTasks)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: TextButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm việc phát sinh'),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ShiftTaskEditor(
                  bookingId: booking.id,
                  mode: ShiftTaskEditorMode.create,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
