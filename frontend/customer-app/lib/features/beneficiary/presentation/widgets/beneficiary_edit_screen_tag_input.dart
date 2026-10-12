import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryEditScreenTagInput extends StatelessWidget {
  const BeneficiaryEditScreenTagInput(
      {super.key,
      required this.removeTag,
      required this.buildLabel,
      required this.label,
      required this.ctrl,
      required this.hint,
      required this.addTag,
      required this.tags,
      required this.setState,
      required this.tagColor});
  final Widget Function(String) buildLabel;
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final void Function(TextEditingController, List<String>) addTag;
  final ValueChanged<String> removeTag;
  final List<String> tags;
  final void Function(void Function()) setState;
  final Color tagColor;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabel(label),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: ctrl,
                decoration: InputDecoration(hintText: hint),
                onFieldSubmitted: (_) => addTag(ctrl, tags),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: () => addTag(ctrl, tags),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.compact),
                ),
                child:
                    const Icon(Icons.add, color: AppColors.primary, size: 22),
              ),
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.control),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: tags
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => removeTag(tag),
                    backgroundColor: tagColor.withValues(alpha: 0.1),
                    side: BorderSide(color: tagColor.withValues(alpha: 0.3)),
                    labelStyle: TextStyle(
                      color: tagColor,
                      fontSize: AppFontSizes.s12,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.micro, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
