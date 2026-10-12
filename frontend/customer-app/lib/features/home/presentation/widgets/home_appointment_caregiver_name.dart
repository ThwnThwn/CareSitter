import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeAppointmentCaregiverName extends StatelessWidget {
  const HomeAppointmentCaregiverName({super.key, required this.caregiverName});
  final String caregiverName;

  @override
  Widget build(BuildContext context) => Text(
        caregiverName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppFontSizes.s13,
          fontWeight: FontWeight.w700,
        ),
      );
}
