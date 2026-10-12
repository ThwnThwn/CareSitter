import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.items});
  final String title;
  final List<Widget> items;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        Material(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3))
                ]),
            child: Column(children: items),
          ),
        ),
      ],
    );
  }
}
