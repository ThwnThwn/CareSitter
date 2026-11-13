import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_dropdown_field.dart';
import '../models/nutrition_medication_draft.dart';

class NutritionMedicationEditor extends StatelessWidget {
  const NutritionMedicationEditor({
    super.key,
    required this.medication,
    required this.index,
    required this.enabled,
    required this.onNameChanged,
    required this.onChanged,
    required this.onRemove,
  });

  final NutritionMedicationDraft medication;
  final int index;
  final bool enabled;
  final VoidCallback onNameChanged;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        key: ObjectKey(medication),
        padding: const EdgeInsets.only(bottom: AppSpacing.section),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Thuốc ${index + 1}',
              style: Theme.of(context).textTheme.titleSmall),
          TextField(
            controller: medication.name,
            enabled: enabled,
            maxLength: 200,
            decoration: const InputDecoration(
                labelText: 'Tên thuốc theo thông tin hiện có'),
            onChanged: (_) => onNameChanged(),
          ),
          TextField(
              controller: medication.dosage,
              enabled: enabled,
              maxLength: 1000,
              decoration: const InputDecoration(
                  labelText: 'Liều dùng đã được hướng dẫn (nếu có)'),
              onChanged: (_) {
                medication.dosageDirty = true;
                onChanged();
              }),
          AppDropdownField<String>(
            initialValue: medication.active == null
                ? 'unknown'
                : medication.active!
                    ? 'active'
                    : 'inactive',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Trạng thái sử dụng'),
            items: const [
              DropdownMenuItem(value: 'unknown', child: Text('Chưa rõ')),
              DropdownMenuItem(value: 'active', child: Text('Đang dùng')),
              DropdownMenuItem(value: 'inactive', child: Text('Đã ngừng dùng')),
            ],
            onChanged: !enabled
                ? null
                : (v) {
                    medication.active = v == 'unknown' ? null : v == 'active';
                    onChanged();
                  },
          ),
          TextButton(
              onPressed: enabled ? onRemove : null,
              child: const Text('Bỏ mục thuốc này')),
        ]),
      );
}
