import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftDetailMapUnavailable extends StatelessWidget {
  const ShiftDetailMapUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      width: double.infinity,
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                color: AppColors.textHint, size: 26),
            SizedBox(height: AppSpacing.tight),
            Text(
              'Chưa có tọa độ để hiển thị bản đồ',
              style: TextStyle(
                  fontSize: AppFontSizes.s13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
