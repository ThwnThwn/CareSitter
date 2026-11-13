import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionHealthSaveButton extends StatelessWidget {
  const NutritionHealthSaveButton({
    super.key,
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.compact,
            horizontal: AppSpacing.md,
          ),
        ),
        onPressed: enabled ? onPressed : null,
        child: const Text('Lưu phần thông tin đã cập nhật'),
      );
}
