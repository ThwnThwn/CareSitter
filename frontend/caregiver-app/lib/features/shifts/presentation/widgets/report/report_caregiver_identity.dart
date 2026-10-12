import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ReportCaregiverIdentity extends StatelessWidget {
  const ReportCaregiverIdentity({super.key, required this.caregiverName});
  final String caregiverName;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    caregiverName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: AppFontSizes.s16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: AppSpacing.tight),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.tight, vertical: AppSpacing.micro),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.tight),
                  ),
                  child: const Text(
                    '✅ Đã xác minh',
                    style: TextStyle(
                        fontSize: AppFontSizes.s10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
