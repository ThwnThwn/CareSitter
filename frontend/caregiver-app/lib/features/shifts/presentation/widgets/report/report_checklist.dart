import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_checklist_task.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_section_card.dart';

/// Section hiển thị checklist công việc của ca.
class ReportChecklist extends StatelessWidget {
  final int completedTasks;
  final int totalTasks;
  final List<String> taskPhotos;

  const ReportChecklist({
    super.key,
    required this.completedTasks,
    required this.totalTasks,
    required this.taskPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalTasks > 0 ? totalTasks : completedTasks;
    final tasks = List.generate(total, (index) => 'Nhiệm vụ ${index + 1}');

    return ReportSectionCard(
      title: '✅ Checklist công việc',
      subtitle: '$completedTasks/${tasks.length} hoàn thành',
      child: Column(
        children: tasks.asMap().entries.map((e) {
          final i = e.key;
          final title = e.value;
          final done = i < completedTasks;
          final hasPhoto = i < taskPhotos.length;
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.inset, vertical: AppSpacing.compact),
            decoration: BoxDecoration(
              color: done
                  ? AppColors.success.withValues(alpha: 0.05)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: done
                    ? AppColors.success.withValues(alpha: 0.25)
                    : AppColors.border,
              ),
            ),
            child: ReportChecklistTask(
                done: done, title: title, hasPhoto: hasPhoto),
          );
        }).toList(),
      ),
    );
  }
}
