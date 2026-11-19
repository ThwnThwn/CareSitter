import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../models/nutrition_profile_item.dart';
import 'nutrition_entry_state.dart';
import 'nutrition_profile_card.dart';

class NutritionEntryBody extends StatelessWidget {
  const NutritionEntryBody({
    super.key,
    required this.profiles,
    required this.onCreateProfile,
    required this.onSelect,
    required this.onRetry,
    this.isLoading = false,
    this.hasError = false,
  });

  final List<NutritionProfileItem> profiles;
  final VoidCallback onCreateProfile;
  final ValueChanged<String> onSelect;
  final VoidCallback onRetry;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      if (isLoading) return const NutritionEntryState.loading();
      if (hasError) return NutritionEntryState.error(onAction: onRetry);
      return NutritionEntryState.empty(onAction: onCreateProfile);
    }
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.section,
          AppSpacing.md,
          AppSpacing.section,
          AppSpacing.xl,
        ),
        children: [
          const _NutritionEntryHeader(),
          const SizedBox(height: AppSpacing.lg),
          for (final profile in profiles)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.compact),
              child: NutritionProfileCard(
                profile: profile,
                onTap: () => onSelect(profile.id),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: onCreateProfile,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Thêm hồ sơ người thân mới'),
          ),
          const SizedBox(height: AppSpacing.md),
          const _NutritionTip(),
        ],
      ),
    );
  }
}

class _NutritionEntryHeader extends StatelessWidget {
  const _NutritionEntryHeader();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chọn người cần lập thực đơn',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Gợi ý được cá nhân hóa theo thông tin sức khỏe và nhu cầu ăn uống đã xác nhận của từng người.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s13,
              height: 1.5,
            ),
          ),
        ],
      );
}

class _NutritionTip extends StatelessWidget {
  const _NutritionTip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary),
            SizedBox(width: AppSpacing.compact),
            Expanded(
              child: Text(
                'Cập nhật hồ sơ khi tình trạng sức khỏe hoặc nhu cầu ăn uống thay đổi để gợi ý phù hợp hơn.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.s12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
}
