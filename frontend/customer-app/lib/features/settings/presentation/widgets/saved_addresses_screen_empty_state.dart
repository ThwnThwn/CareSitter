import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SavedAddressesScreenEmptyState extends StatelessWidget {
  const SavedAddressesScreenEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.compact),
      padding: const EdgeInsets.all(AppSpacing.inset),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_off_outlined,
              color: AppColors.textSecondary, size: 20),
          SizedBox(width: AppSpacing.control),
          Expanded(
            child: Text(
              'Bạn chưa có địa chỉ nào. Thêm ngay để đặt lịch.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s13),
            ),
          ),
        ],
      ),
    );
  }
}
