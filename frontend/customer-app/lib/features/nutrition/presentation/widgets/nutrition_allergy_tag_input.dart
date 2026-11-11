import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class NutritionAllergyTagInput extends StatelessWidget {
  const NutritionAllergyTagInput({
    super.key,
    required this.tags,
    required this.input,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.maxLength,
    required this.onChanged,
    required this.onSubmitted,
    required this.onRemove,
  });

  final List<String> tags;
  final TextEditingController input;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final int maxLength;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        key: const ValueKey('nutrition-allergies-field'),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: hasError ? AppColors.error : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in tags)
              _NutritionAllergyChip(
                tag: tag,
                enabled: enabled,
                onRemove: () => onRemove(tag),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 190),
              child: IntrinsicWidth(
                child: TextField(
                  key: const ValueKey('nutrition-allergies-input'),
                  controller: input,
                  focusNode: focusNode,
                  enabled: enabled,
                  maxLength: maxLength,
                  textInputAction: TextInputAction.done,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  decoration: const InputDecoration(
                    hintText: 'Nhập thực phẩm rồi nhấn Enter...',
                    counterText: '',
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _NutritionAllergyChip extends StatelessWidget {
  const _NutritionAllergyChip({
    required this.tag,
    required this.enabled,
    required this.onRemove,
  });

  final String tag;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InputChip(
        label: Text(tag),
        onDeleted: enabled ? onRemove : null,
        deleteButtonTooltipMessage: 'Xoá $tag',
        deleteIcon: const Icon(Icons.close_rounded, size: 16),
        backgroundColor: AppColors.primaryContainer,
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
}
