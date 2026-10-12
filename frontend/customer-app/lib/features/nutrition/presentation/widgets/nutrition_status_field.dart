import 'package:flutter/material.dart';

class NutritionStatusField extends StatelessWidget {
  const NutritionStatusField(
      {super.key,
      required this.label,
      required this.value,
      required this.options,
      required this.enabled,
      required this.onChanged});
  final String label, value;
  final Map<String, String> options;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
      initialValue: options.containsKey(value) ? value : 'unknown',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: enabled
          ? (value) {
              if (value != null) onChanged(value);
            }
          : null);
}
