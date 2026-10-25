import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SettingsProfileEditLink extends StatelessWidget {
  const SettingsProfileEditLink({super.key, required this.onEditProfile});

  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onEditProfile,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Chỉnh sửa hồ sơ'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.compact),
            textStyle: const TextStyle(
              fontSize: AppFontSizes.s14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}
