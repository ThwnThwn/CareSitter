import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SettingsProfileEditLink extends StatelessWidget {
  const SettingsProfileEditLink({super.key, required this.callbackAction2});
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: callbackAction2,
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.compact)),
          child: const Text('Chỉnh sửa hồ sơ',
              style: TextStyle(
                  fontSize: AppFontSizes.s14, fontWeight: FontWeight.w600)),
        ),
      );
}
