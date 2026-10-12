import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class DocumentStatusOverallStatus extends StatelessWidget {
  const DocumentStatusOverallStatus(
      {super.key, required this.approved, required this.statusText});
  final bool approved;
  final String statusText;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: [
          Icon(
              approved
                  ? Icons.verified_user_rounded
                  : Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                      fontSize: AppFontSizes.s18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  approved
                      ? 'Bạn đủ điều kiện nhận ca theo trạng thái từ hệ thống.'
                      : 'Hãy cập nhật hồ sơ khi backend cung cấp yêu cầu bổ sung.',
                  style: TextStyle(
                      fontSize: AppFontSizes.s13,
                      color: AppColors.primary.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
