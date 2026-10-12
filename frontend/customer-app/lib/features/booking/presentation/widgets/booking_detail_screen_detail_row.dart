import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingDetailScreenDetailRow extends StatelessWidget {
  const BookingDetailScreenDetailRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.control),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSizes.s11)),
              const SizedBox(height: AppSpacing.micro),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppFontSizes.s13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
