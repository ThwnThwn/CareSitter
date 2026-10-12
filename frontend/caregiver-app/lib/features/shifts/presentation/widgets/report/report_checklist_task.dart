import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ReportChecklistTask extends StatelessWidget {
  const ReportChecklistTask(
      {super.key,
      required this.done,
      required this.title,
      required this.hasPhoto});
  final bool done;
  final String title;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: done ? AppColors.success : AppColors.textHint,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.control),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: AppFontSizes.s14,
                fontWeight: FontWeight.w500,
                color: done ? AppColors.textSecondary : AppColors.textPrimary,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (hasPhoto || done)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.tight, vertical: AppSpacing.tiny),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.tight),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_rounded, size: 11, color: AppColors.primary),
                  SizedBox(width: AppSpacing.tiny),
                  Text('Có ảnh',
                      style: TextStyle(
                          fontSize: AppFontSizes.s10,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      );
}
