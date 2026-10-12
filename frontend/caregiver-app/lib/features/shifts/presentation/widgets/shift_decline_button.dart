import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftDeclineButton extends StatelessWidget {
  const ShiftDeclineButton({super.key, required this.callbackAction1});
  final Future<void> Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Expanded(
        child: OutlinedButton(
          onPressed: callbackAction1,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.inset),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          child: const Text('Từ chối',
              style: TextStyle(color: AppColors.textPrimary)),
        ),
      );
}
