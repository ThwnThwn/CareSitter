import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'beneficiary_field_label.dart';

class BeneficiaryConditionInput extends StatelessWidget {
  const BeneficiaryConditionInput({
    super.key,
    required this.controller,
    required this.tags,
    required this.onAdd,
    required this.onRemove,
  });
  final TextEditingController controller;
  final List<String> tags;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const BeneficiaryFieldLabel(text: 'Nhu cầu hỗ trợ / Lưu ý'),
        Row(children: [
          Expanded(
              child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
                hintText:
                    'VD: Hay quên, khó di chuyển, cần đồng hành... nhấn + để thêm'),
            onFieldSubmitted: (_) => onAdd(),
          )),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
              onPressed: onAdd, tooltip: 'Thêm lưu ý', icon: const Icon(Icons.add)),
        ]),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.control),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.tight, children: [
            for (final tag in tags)
              Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => onRemove(tag),
                backgroundColor: AppColors.info.withValues(alpha: 0.1),
                side: BorderSide(color: AppColors.info.withValues(alpha: 0.3)),
                labelStyle: const TextStyle(color: AppColors.info),
              ),
          ]),
        ],
      ]);
}
