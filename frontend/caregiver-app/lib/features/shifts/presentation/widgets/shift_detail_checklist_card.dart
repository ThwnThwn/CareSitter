import 'package:caregiver_app/features/shifts/presentation/widgets/shift_checklist_task.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_checklist_progress.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_checklist_notes.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftDetailChecklistCard extends StatelessWidget {
  const ShiftDetailChecklistCard(
      {super.key, required this.booking, required this.beneficiary});
  final ShiftModel booking;
  final ShiftBeneficiaryModel beneficiary;
  @override
  Widget build(BuildContext context) {
    final hasTasks = booking.tasks.isNotEmpty;
    final hasNotes = _hasMeaningfulNotes(beneficiary.notes);
    final completedCount =
        hasTasks ? booking.tasks.where((t) => t.isCompleted).length : 0;
    final total = hasTasks ? booking.tasks.length : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTasks) ...[
            ShiftChecklistProgress(
                total: total, completedCount: completedCount),
            const SizedBox(height: AppSpacing.compact),
          ],
          if (!hasTasks)
            const Text('Không có checklist công việc đặc biệt.',
                style: TextStyle(
                    fontSize: AppFontSizes.s14, color: AppColors.textSecondary))
          else
            ...booking.tasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.control),
                  child: ShiftChecklistTask(task: task),
                )),
          if (hasNotes) ...[
            const Divider(height: 20, color: AppColors.border),
            ShiftChecklistNotes(beneficiary: beneficiary),
          ],
        ],
      ),
    );
  }
}

bool _hasMeaningfulNotes(String notes) {
  final normalized = notes.trim().toLowerCase();
  return normalized.isNotEmpty &&
      !const {
        'không có',
        'khong co',
        'chưa có ghi chú',
        'none',
        'n/a',
      }.contains(normalized);
}
