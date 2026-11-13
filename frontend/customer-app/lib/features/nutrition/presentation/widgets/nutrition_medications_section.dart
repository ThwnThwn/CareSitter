import 'package:flutter/material.dart';
import '../models/nutrition_medication_draft.dart';
import 'nutrition_medication_editor.dart';

class NutritionMedicationsSection extends StatelessWidget {
  const NutritionMedicationsSection({
    super.key,
    required this.medications,
    required this.legacy,
    required this.enabled,
    required this.onNameChanged,
    required this.onChanged,
    required this.onRemove,
    required this.onAdd,
  });

  final List<NutritionMedicationDraft> medications;
  final bool legacy;
  final bool enabled;
  final VoidCallback onNameChanged;
  final VoidCallback onChanged;
  final ValueChanged<NutritionMedicationDraft> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (legacy)
            const Text(
              'Danh sách thuốc cũ chưa đúng định dạng. Thông tin được giữ nguyên và cần kiểm tra lại trong hồ sơ.',
            ),
          for (var i = 0; i < medications.length; i++)
            NutritionMedicationEditor(
              key: ObjectKey(medications[i]),
              medication: medications[i],
              index: i,
              enabled: enabled,
              onNameChanged: onNameChanged,
              onChanged: onChanged,
              onRemove: () => onRemove(medications[i]),
            ),
          if (!legacy && medications.length < 40)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Thêm thuốc đã được kê / đang dùng'),
                onPressed: enabled ? onAdd : null,
              ),
            ),
        ],
      );
}
