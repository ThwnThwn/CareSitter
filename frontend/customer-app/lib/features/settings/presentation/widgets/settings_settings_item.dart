import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SettingsSettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const SettingsSettingsItem(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.compact)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s14,
                fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFontSizes.s12))
            : null,
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textHint, size: 20),
        onTap: onTap,
      ),
      const Divider(height: 1, indent: 56, color: AppColors.divider),
    ]);
  }
}
