import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ReportCaregiverAvatar extends StatelessWidget {
  const ReportCaregiverAvatar({super.key, required this.caregiverName});
  final String caregiverName;

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            caregiverName.isNotEmpty ? caregiverName[0].toUpperCase() : 'C',
            style: const TextStyle(
                fontSize: AppFontSizes.s24,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
        ),
      );
}
