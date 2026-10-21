import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/models/health_profile_model.dart';
import 'nutrition_health_fields.dart';
import 'nutrition_notes_fields.dart';
import 'nutrition_preferences_panel.dart';
import 'nutrition_reported_health_fields.dart';
import 'nutrition_required_header.dart';

class NutritionHealthForm extends StatefulWidget {
  const NutritionHealthForm(
      {super.key,
      required this.health,
      required this.enabled,
      required this.onDirtyChanged,
      required this.onSave});
  final HealthProfileModel health;
  final bool enabled;
  final ValueChanged<bool> onDirtyChanged;
  final ValueChanged<Map<String, dynamic>> onSave;
  @override
  State<NutritionHealthForm> createState() => _NutritionHealthFormState();
}

class _NutritionHealthFormState extends State<NutritionHealthForm> {
  final _allergies = TextEditingController(),
      _conditions = TextEditingController();
  final Map<String, dynamic> _changes = {};
  late String _allergyStatus, _conditionStatus, _dietaryPattern, _nutritionGoal;
  @override
  void initState() {
    super.initState();
    String labels(Object? raw) => raw is List
        ? raw
            .map((e) => e is Map ? e['label'] ?? e['code'] ?? jsonEncode(e) : e)
            .join('; ')
        : '';
    _allergies.text = labels(widget.health['allergies']);
    _conditions.text = labels(widget.health['chronicConditions']);
    _allergyStatus = widget.health.allergyStatus;
    final history = widget.health['healthHistory'];
    final profile = history is Map && history['nutrition'] is Map
        ? history['nutrition'] as Map
        : const {};
    _conditionStatus = profile['conditionsStatus']?.toString() ?? 'unknown';
    _dietaryPattern = profile['dietaryPattern']?.toString() ?? 'regular';
    _nutritionGoal = profile['nutritionGoal']?.toString() ?? 'maintain';
  }

  void _change(String key, Object? value) {
    setState(() {
      _changes[key] = value;
    });
    widget.onDirtyChanged(true);
  }

  void _structured(Map<String, dynamic> value) {
    setState(() {
      for (final entry in value.entries) {
        if (entry.key != 'nutritionProfile') {
          _changes[entry.key] = entry.value;
        }
      }
      final incoming = value['nutritionProfile'];
      if (incoming is Map) {
        _changes['nutritionProfile'] = {
          ...?_changes['nutritionProfile'] as Map<String, dynamic>?,
          ...Map<String, dynamic>.from(incoming),
        };
      }
    });
    widget.onDirtyChanged(true);
  }

  void _changeNutritionField(String field, String value) => _structured({
        'nutritionProfile': {field: value}
      });

  List<String> _items(String value) =>
      value.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  void _save() => widget.onSave(Map.of(_changes));

  @override
  void dispose() {
    _allergies.dispose();
    _conditions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const NutritionRequiredHeader(),
        const SizedBox(height: AppSpacing.md),
        NutritionReportedHealthFields(
          enabled: widget.enabled,
          allergyStatus: _allergyStatus,
          conditionStatus: _conditionStatus,
          allergyController: _allergies,
          conditionController: _conditions,
          onAllergyStatusChanged: (value) {
            _allergyStatus = value;
            _change('foodAllergyStatus', value);
          },
          onConditionStatusChanged: (value) {
            _conditionStatus = value;
            _changeNutritionField('conditionsStatus', value);
          },
          onAllergiesChanged: (value) => _change('allergies', _items(value)),
          onConditionsChanged: (value) =>
              _change('chronicConditions', _items(value)),
        ),
        NutritionPreferencesPanel(
          enabled: widget.enabled,
          dietaryPattern: _dietaryPattern,
          nutritionGoal: _nutritionGoal,
          onDietaryPatternChanged: (value) {
            _dietaryPattern = value;
            _changeNutritionField('dietaryPattern', value);
          },
          onNutritionGoalChanged: (value) {
            _nutritionGoal = value;
            _changeNutritionField('nutritionGoal', value);
          },
        ),
        const SizedBox(height: AppSpacing.compact),
        NutritionHealthFields(
            health: widget.health,
            enabled: widget.enabled,
            onChanged: _structured),
        const SizedBox(height: AppSpacing.compact),
        NutritionNotesFields(
            health: widget.health,
            enabled: widget.enabled,
            onChanged: (key, value) => _change(key, value)),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.compact,
                horizontal: AppSpacing.md,
              ),
            ),
            onPressed: widget.enabled ? _save : null,
            child: const Text('Lưu phần thông tin đã cập nhật')),
      ]);
}
