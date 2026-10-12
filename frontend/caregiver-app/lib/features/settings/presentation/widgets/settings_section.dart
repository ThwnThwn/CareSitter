import 'package:caregiver_app/features/settings/presentation/models/settings_item.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.items});
  final String title;
  final List<SettingsItem> items;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: AppFontSizes.s14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Column(
              children: items.asMap().entries.map((e) {
                final isLast = e.key == items.length - 1;
                return Column(
                  children: [
                    ListTile(
                      leading:
                          Icon(e.value.icon, color: AppColors.textSecondary),
                      title: Text(
                        e.value.title,
                        style: const TextStyle(
                          fontSize: AppFontSizes.s15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: e.value.subtitle != null
                          ? Text(e.value.subtitle!,
                              style: const TextStyle(
                                  fontSize: AppFontSizes.s12,
                                  color: AppColors.primary))
                          : null,
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textHint),
                      onTap: e.value.onTap,
                    ),
                    if (!isLast) const Divider(height: 1, indent: 56),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
