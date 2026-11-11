import 'package:flutter/material.dart';

class NutritionMedicationDraft {
  final Map<String, dynamic> original;
  final TextEditingController name, dosage;
  bool? active;
  bool dosageDirty = false;
  NutritionMedicationDraft(this.original)
      : name = TextEditingController(text: original['name'] as String),
        dosage =
            TextEditingController(text: original['dosage']?.toString() ?? ''),
        active = original['is_active'] is bool
            ? original['is_active'] as bool
            : null;
  Map<String, dynamic> value() => {
        ...original,
        'name': name.text.trim(),
        if (dosageDirty) 'dosage': dosage.text.trim(),
        if (active != null) 'is_active': active,
      }..removeWhere((key, _) => key == 'is_active' && active == null);
  void dispose() {
    name.dispose();
    dosage.dispose();
  }
}
