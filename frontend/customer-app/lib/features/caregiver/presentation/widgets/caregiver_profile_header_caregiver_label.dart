import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileHeaderCaregiverLabel extends StatelessWidget {
  const CaregiverProfileHeaderCaregiverLabel(
      {super.key, required this.caregiver});
  final CaregiverModel caregiver;

  @override
  Widget build(BuildContext context) => Text(
        caregiver.isOnline
            ? '● Đang rảnh${caregiver.yearsOfExperience != null ? ' • ${caregiver.yearsOfExperience} năm kinh nghiệm' : ''}'
            : '○ Hiện đang bận',
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: AppFontSizes.s13),
      );
}
