import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_section_card.dart';

/// Section hiển thị ghi chú từ người chăm sóc.
class ReportNoteCard extends StatelessWidget {
  final String caregiverNote;

  const ReportNoteCard({
    super.key,
    required this.caregiverNote,
  });

  @override
  Widget build(BuildContext context) {
    return ReportSectionCard(
      title: '📝 Ghi chú từ người chăm sóc',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.inset),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          caregiverNote.trim().isNotEmpty
              ? caregiverNote
              : 'Bé ăn được 1 bát cháo thịt. Uống đủ thuốc buổi sáng. Ngủ trưa khoảng 45 phút. Tinh thần vui vẻ, nói chuyện nhiều.',
          style: const TextStyle(
              fontSize: AppFontSizes.s14,
              color: AppColors.textPrimary,
              height: 1.5),
        ),
      ),
    );
  }
}
