import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:flutter/material.dart';

import 'nutrition_meal_details.dart';

/// Card hiển thị một bữa ăn theo layout compact: section header (meal type)
/// + từng món dạng row thumbnail-left / tên-right, giống tham khảo Meal Plan.
class NutritionMealCard extends StatelessWidget {
  const NutritionMealCard({
    super.key,
    required this.meal,
    required this.loading,
    required this.canReplace,
    required this.onReplace,
  });

  final NutritionMealModel meal;
  final bool loading;
  final bool canReplace;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Bữa ăn: ${meal.name}',
        child: _MealCompactRow(
          meal: meal,
          loading: loading,
          canReplace: canReplace,
          onReplace: onReplace,
        ),
      );
}

// ── Compact row (thumbnail + detail) ─────────────────────────────────────────

class _MealCompactRow extends StatelessWidget {
  const _MealCompactRow({
    required this.meal,
    required this.loading,
    required this.canReplace,
    required this.onReplace,
  });

  final NutritionMealModel meal;
  final bool loading;
  final bool canReplace;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.section,
        right: AppSpacing.section,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactMealRow(meal: meal),
          if (canReplace)
            Padding(
              padding: const EdgeInsets.only(
                left: _CompactMealRow._thumbSize + AppSpacing.compact,
                top: AppSpacing.xs,
              ),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: loading ? null : onReplace,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Chọn món thay thế'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(
              left: _CompactMealRow._thumbSize + AppSpacing.compact,
            ),
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: NutritionMealDetails(meal: meal),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMealRow extends StatelessWidget {
  const _CompactMealRow({required this.meal});

  final NutritionMealModel meal;

  static const double _thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final metadata = _MealMetadataExt.forType(meal.mealType);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Thumbnail ──────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.compact),
          child: SizedBox.square(
            dimension: _thumbSize,
            child: _MealThumbnail(meal: meal, metadata: metadata),
          ),
        ),
        const SizedBox(width: AppSpacing.compact),
        // ── Name + servings ────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
              if (meal.servings != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${nutritionDisplayNumber(meal.servings!)} phần',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MealThumbnail extends StatelessWidget {
  const _MealThumbnail({required this.meal, required this.metadata});

  final NutritionMealModel meal;
  final _MealMetadataExt metadata;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _httpsImageUrl(meal.imageUrl);
    final semanticLabel =
        meal.imageAlt ?? 'Ảnh minh hoạ ${metadata.label.toLowerCase()}';
    final fallback = Image.asset(
      metadata.imageAsset,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: AppColors.primaryContainer,
        child: Center(
          child: Icon(metadata.icon, color: AppColors.primary, size: 24),
        ),
      ),
    );
    if (imageUrl == null) return fallback;
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  static String? _httpsImageUrl(String? value) {
    final uri = value == null ? null : Uri.tryParse(value);
    return uri?.scheme == 'https' && uri?.host.isNotEmpty == true
        ? value
        : null;
  }
}

// ── Metadata helper (tách khỏi nutrition_meal_overview để tránh import vòng) ─

class _MealMetadataExt {
  const _MealMetadataExt(this.label, this.icon, this.imageAsset);
  final String label;
  final IconData icon;
  final String imageAsset;

  static _MealMetadataExt forType(String type) => switch (type) {
        'lunch' => const _MealMetadataExt('Bữa trưa', Icons.wb_sunny_outlined,
            'assets/images/nutrition-lunch-illustration.jpg'),
        'dinner' => const _MealMetadataExt('Bữa tối', Icons.nightlight_round,
            'assets/images/nutrition-dinner-illustration.jpg'),
        _ => const _MealMetadataExt('Bữa sáng', Icons.wb_twilight_outlined,
            'assets/images/nutrition-breakfast-illustration.jpg'),
      };
}
