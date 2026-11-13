import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/nutrition_recipe_image_model.dart';
import 'nutrition_reference_text.dart';

class NutritionMealPhotos extends StatelessWidget {
  const NutritionMealPhotos({super.key, required this.images});

  final List<NutritionRecipeImageModel> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ảnh tham khảo', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final image in images) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.compact),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  image.url,
                  fit: BoxFit.cover,
                  semanticLabel: image.dishName,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: AppColors.primaryContainer,
                    child: Icon(Icons.restaurant, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            Text(image.dishName,
                style: Theme.of(context).textTheme.labelMedium),
            if (image.matchKind == 'related_dish')
              Text('Ảnh món tương tự',
                  style: Theme.of(context).textTheme.bodySmall),
            NutritionReferenceText(image.sourceUrl, label: image.attribution),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
