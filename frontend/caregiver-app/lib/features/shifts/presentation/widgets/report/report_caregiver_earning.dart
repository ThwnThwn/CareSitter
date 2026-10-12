import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ReportCaregiverEarning extends StatelessWidget {
  const ReportCaregiverEarning({super.key, required this.caregiverEarning});
  final double caregiverEarning;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text('Chi phí',
              style: TextStyle(
                  fontSize: AppFontSizes.s11, color: AppColors.textSecondary)),
          Text(
            '${formatVnd(caregiverEarning, separator: ',', suffix: '', round: true)} đ',
            style: const TextStyle(
                fontSize: AppFontSizes.s15,
                fontWeight: FontWeight.w800,
                color: AppColors.primary),
          ),
        ],
      );
}
