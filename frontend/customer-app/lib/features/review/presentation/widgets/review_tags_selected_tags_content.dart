import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class ReviewTagsSelectedTagsContent extends StatelessWidget {
  const ReviewTagsSelectedTagsContent(
      {super.key,
      required this.tags,
      required this.selectedTags,
      required this.setState});
  final List<String> tags;
  final Set<String> selectedTags;
  final void Function(void Function()) setState;
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Điểm nổi bật',
                style: TextStyle(
                    fontSize: AppFontSizes.s14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.control),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                final isSelected = selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () => setState(() => isSelected
                      ? selectedTags.remove(tag)
                      : selectedTags.add(tag)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.inset, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    child: Text(tag,
                        style: TextStyle(
                          fontSize: AppFontSizes.s13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        )),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
}
