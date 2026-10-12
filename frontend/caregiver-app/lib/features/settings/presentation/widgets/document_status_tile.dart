import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class DocumentStatusTile extends StatelessWidget {
  const DocumentStatusTile({super.key, required this.url, required this.title});
  final String? url;
  final String title;
  @override
  Widget build(BuildContext context) {
    final available = url != null && url!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            available
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: available ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(
            available ? 'Đã tải lên' : 'Còn thiếu',
            style: TextStyle(
              color: available ? AppColors.success : AppColors.warning,
              fontSize: AppFontSizes.s12,
            ),
          ),
        ],
      ),
    );
  }
}
