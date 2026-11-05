import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/models/health_profile_model.dart';
import '../../domain/nutrition_personalization_rules.dart';
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
      required this.onSave,
      this.showSaveButton = true,
      this.missingFields = const []});
  final bool showSaveButton;
  final HealthProfileModel health;
  final bool enabled;
  final ValueChanged<bool> onDirtyChanged;
  final ValueChanged<Map<String, dynamic>> onSave;
  final List<String> missingFields;
  @override
  State<NutritionHealthForm> createState() => NutritionHealthFormState();
}

class NutritionHealthFormState extends State<NutritionHealthForm> {
  final _allergies = TextEditingController(),
      _conditions = TextEditingController();
  final Map<String, dynamic> _changes = {};
  late String _allergyStatus, _conditionStatus, _dietaryPattern, _nutritionGoal;
  bool _showErrors = false;
  final _allergyStatusKey = GlobalKey();
  final _allergyDetailKey = GlobalKey();
  final _conditionStatusKey = GlobalKey();
  final _conditionDetailKey = GlobalKey();
  final _structuredKey = GlobalKey<NutritionHealthFieldsState>();
  final _allergyFocus = FocusNode();
  final _conditionFocus = FocusNode();

  @override
  void didUpdateWidget(covariant NutritionHealthForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.missingFields.isNotEmpty &&
        widget.missingFields.join('|') != oldWidget.missingFields.join('|')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => revealFirstError());
    }
  }

  Future<void> revealFirstError() async {
    if (!mounted) return;
    final allergyDetail = widget.missingFields
        .any((field) => field == 'allergies' || field.startsWith('allergies/'));
    final conditionDetail = widget.missingFields.any((field) =>
        field == 'chronicConditions' || field.startsWith('chronicConditions/'));
    final allergyStatus = widget.missingFields.contains('foodAllergyStatus') ||
        (_showErrors &&
            (_allergyStatus == 'unknown' ||
                (_allergyStatus == 'reported_none' &&
                    _allergies.text.isNotEmpty)));
    final conditionStatus = widget.missingFields.contains('conditionsStatus') ||
        (_showErrors &&
            (_conditionStatus == 'unknown' ||
                (_conditionStatus == 'reported_none' &&
                    _conditions.text.isNotEmpty)));
    final missingAllergyDetail = _showErrors &&
        _allergyStatus == 'reported_present' &&
        _allergies.text.trim().isEmpty;
    final missingConditionDetail = _showErrors &&
        _conditionStatus == 'reported_present' &&
        _conditions.text.trim().isEmpty;
    final targetKey = allergyStatus
        ? _allergyStatusKey
        : allergyDetail || missingAllergyDetail
            ? _allergyDetailKey
            : conditionStatus
                ? _conditionStatusKey
                : conditionDetail || missingConditionDetail
                    ? _conditionDetailKey
                    : null;
    if (targetKey == null) {
      await _structuredKey.currentState?.revealFirstError();
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final target = targetKey.currentContext;
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(target,
        alignment: 0.18,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic);
    if (!mounted) return;
    if (targetKey == _allergyDetailKey) _allergyFocus.requestFocus();
    if (targetKey == _conditionDetailKey) _conditionFocus.requestFocus();
  }

  NutritionPersonalizationReadiness validate() {
    final history = widget.health['healthHistory'];
    final saved = history is Map && history['nutrition'] is Map
        ? Map<String, dynamic>.from(history['nutrition'] as Map)
        : <String, dynamic>{};
    final profile = {
      ...saved,
      ...?_changes['nutritionProfile'] as Map<String, dynamic>?
    };
    final result = NutritionPersonalizationRules.evaluate(
      allergyStatus: _allergyStatus,
      allergies: _items(_allergies.text),
      conditionStatus: _conditionStatus,
      chronicConditions: _items(_conditions.text),
      medicationsStatus: profile['medicationsStatus']?.toString() ?? 'unknown',
      medications: _changes['medications'] ?? widget.health['medications'],
      feedingRoute: profile['feedingRoute']?.toString() ?? 'unknown',
      swallowingStatus: profile['swallowingStatus']?.toString() ?? 'unknown',
      fluidRestriction: profile['fluidRestriction']?.toString() ?? 'unknown',
      electrolyteRestriction:
          profile['electrolyteRestriction']?.toString() ?? 'unknown',
    );
    setState(() => _showErrors = !result.isReady);
    return result;
  }

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
    if (widget.missingFields.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => revealFirstError());
    }
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
  Map<String, dynamic> get changes => Map.of(_changes);

  @override
  void dispose() {
    _allergies.dispose();
    _conditions.dispose();
    _allergyFocus.dispose();
    _conditionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const NutritionRequiredHeader(),
        const SizedBox(height: AppSpacing.md),
        NutritionReportedHealthFields(
          enabled: widget.enabled,
          showErrors: _showErrors,
          missingFields: widget.missingFields,
          allergyStatusKey: _allergyStatusKey,
          allergyDetailKey: _allergyDetailKey,
          conditionStatusKey: _conditionStatusKey,
          conditionDetailKey: _conditionDetailKey,
          allergyFocusNode: _allergyFocus,
          conditionFocusNode: _conditionFocus,
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
            key: _structuredKey,
            health: widget.health,
            enabled: widget.enabled,
            showErrors: _showErrors,
            missingFields: widget.missingFields,
            onChanged: _structured),
        const SizedBox(height: AppSpacing.compact),
        NutritionNotesFields(
            health: widget.health,
            enabled: widget.enabled,
            onChanged: (key, value) => _change(key, value)),
        const SizedBox(height: AppSpacing.md),
        if (widget.showSaveButton)
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
