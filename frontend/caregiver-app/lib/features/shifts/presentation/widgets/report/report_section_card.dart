import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Card bọc ngoài mỗi section báo cáo ca.
/// Dùng chung bởi Timeline, Checklist, PhotoGallery, NoteCard.
class ReportSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const ReportSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.section),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFontSizes.s15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(subtitle!,
                    style: const TextStyle(
                        fontSize: AppFontSizes.s13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
