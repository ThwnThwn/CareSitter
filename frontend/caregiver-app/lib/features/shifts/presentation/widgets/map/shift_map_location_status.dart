import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftMapLocationStatus extends StatelessWidget {
  const ShiftMapLocationStatus(
      {super.key, required this.message, required this.onRetryLocation});
  final String message;
  final void Function() onRetryLocation;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: AppFontSizes.s12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetryLocation,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
}
