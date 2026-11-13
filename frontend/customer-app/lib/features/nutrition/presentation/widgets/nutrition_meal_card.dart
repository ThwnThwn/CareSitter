import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:flutter/material.dart';

import '../models/nutrition_meal_presentation.dart';
import 'nutrition_meal_details.dart';
import 'nutrition_meal_reasons.dart';
import '../../data/models/nutrition_recommendation_trace_model.dart';

/// Card hiển thị một bữa ăn theo layout compact: section header (meal type)
/// + từng món dạng row thumbnail-left / tên-right, giống tham khảo Meal Plan.
class NutritionMealCard extends StatelessWidget {
  const NutritionMealCard({
    super.key,
    required this.meal,
    required this.loading,
    required this.canReplace,
    required this.onReplace,
    this.trace,
  });

  final NutritionMealModel meal;
  final bool loading;
  final bool canReplace;
  final VoidCallback onReplace;
  final NutritionRecommendationTraceModel? trace;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: 'Bữa ăn: ${meal.name}',
        child: _MealCompactRow(
          meal: meal,
          loading: loading,
          canReplace: canReplace,
          onReplace: onReplace,
          trace: trace,
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
    required this.trace,
  });

  final NutritionMealModel meal;
  final bool loading;
  final bool canReplace;
  final VoidCallback onReplace;
  final NutritionRecommendationTraceModel? trace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: const Border.fromBorderSide(
                BorderSide(color: AppColors.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.inset),
                  child: _CompactMealRow(meal: meal),
                ),
                const Divider(height: 1),
                NutritionMealReasons(meal: meal, trace: trace),
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
                const Divider(height: 1),
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: Material(
                    type: MaterialType.transparency,
                    child: NutritionMealDetails(meal: meal),
                  ),
                ),
              ],
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

  static const double _thumbSize = 64;

  @override
  Widget build(BuildContext context) {
    final metadata = NutritionMealPresentation.forType(meal.mealType);
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              if (meal.servings != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${nutritionDisplayNumber(meal.servings!)} phần${_energyLabel(meal)}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _energyLabel(NutritionMealModel meal) {
    final energy = meal.energyKcal;
    return energy == null ? '' : ' • ${nutritionDisplayNumber(energy)} kcal';
  }
}

class _MealThumbnail extends StatelessWidget {
  const _MealThumbnail({required this.meal, required this.metadata});

  final NutritionMealModel meal;
  final NutritionMealPresentation metadata;

  @override
  Widget build(BuildContext context) {
    final images = meal.images;
    if (images.isNotEmpty) {
      Widget photo(int index) => Image.network(
            images[index].url,
            fit: BoxFit.cover,
            semanticLabel: 'Ảnh tham khảo ${images[index].dishName}',
            errorBuilder: (_, __, ___) => ColoredBox(
              color: AppColors.primaryContainer,
              child: Icon(metadata.icon, color: AppColors.primary, size: 20),
            ),
          );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: photo(0)),
          if (images.length > 1) ...[
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: photo(1)),
                  if (images.length > 2) ...[
                    const SizedBox(height: 2),
                    Expanded(child: photo(2)),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    }
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
