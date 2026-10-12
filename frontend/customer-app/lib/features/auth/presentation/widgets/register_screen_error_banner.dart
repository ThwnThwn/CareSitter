import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class RegisterScreenErrorBanner extends StatelessWidget {
  const RegisterScreenErrorBanner({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.compact),
      decoration: BoxDecoration(
        color: AppColors.authErrorSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.authErrorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.control),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
