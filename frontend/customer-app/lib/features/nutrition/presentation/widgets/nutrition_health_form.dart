import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/models/health_profile_model.dart';
import 'nutrition_health_fields.dart';
import 'nutrition_status_field.dart';
import 'nutrition_notes_fields.dart';

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
  late String _allergyStatus, _conditionStatus;
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
    _conditionStatus = history is Map && history['nutrition'] is Map
        ? history['nutrition']['conditionsStatus']?.toString() ?? 'unknown'
        : 'unknown';
  }

  void _change(String key, Object? value) {
    setState(() {
      _changes[key] = value;
    });
    widget.onDirtyChanged(true);
  }

  void _structured(Map<String, dynamic> value) {
    final existing = _changes['nutritionProfile'] as Map<String, dynamic>?;
    _changes.addAll({
      ...value,
      if (existing?['conditionsStatus'] != null)
        'nutritionProfile': {
          ...?value['nutritionProfile'] as Map<String, dynamic>?,
          'conditionsStatus': existing!['conditionsStatus']
        }
    });
    widget.onDirtyChanged(true);
  }

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
        Text('Thông tin bắt buộc cho gợi ý cá nhân hóa',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Hãy xác nhận bệnh lý và dị ứng đã biết. Khi có thông tin, ghi rõ '
          'để hệ thống loại các món không phù hợp; không dùng mục này để tự chẩn đoán.',
        ),
        const SizedBox(height: AppSpacing.md),
        NutritionStatusField(
            label: 'Dị ứng thực phẩm',
            value: _allergyStatus,
            enabled: widget.enabled,
            options: const {
              'unknown': 'Chưa rõ',
              'reported_present': 'Có dị ứng thực phẩm',
              'reported_none': 'Đã xác nhận không có'
            },
            onChanged: (v) {
              _allergyStatus = v;
              _change('foodAllergyStatus', v);
            }),
        if (_allergyStatus == 'reported_present' || _allergies.text.isNotEmpty)
          TextField(
              controller: _allergies,
              enabled: widget.enabled,
              maxLength: 1000,
              onChanged: (v) => _change('allergies', _items(v)),
              decoration: const InputDecoration(
                  labelText: 'Thực phẩm gây dị ứng *',
                  helperText: 'Bắt buộc khi có dị ứng. Ngăn cách bằng dấu ;')),
        const SizedBox(height: AppSpacing.compact),
        NutritionStatusField(
            label: 'Thông tin bệnh lý hiện có',
            value: _conditionStatus,
            enabled: widget.enabled,
            options: const {
              'unknown': 'Chưa rõ / cần cập nhật',
              'reported_present': 'Có thông tin bệnh lý',
              'reported_none': 'Gia đình xác nhận chưa có bệnh lý'
            },
            onChanged: (v) {
              _conditionStatus = v;
              _change('nutritionProfile', {
                ...?_changes['nutritionProfile'] as Map<String, dynamic>?,
                'conditionsStatus': v
              });
            }),
        if (_conditionStatus == 'reported_present' ||
            _conditions.text.isNotEmpty)
          TextField(
              controller: _conditions,
              enabled: widget.enabled,
              maxLength: 2000,
              onChanged: (v) => _change('chronicConditions', _items(v)),
              decoration: const InputDecoration(
                  labelText: 'Bệnh lý đã biết *',
                  helperText:
                      'Bắt buộc khi có bệnh. Chỉ nhập thông tin đã được ghi nhận; ngăn cách bằng dấu ;.')),
        const SizedBox(height: AppSpacing.compact),
        NutritionHealthFields(
            health: widget.health,
            enabled: widget.enabled,
            onChanged: _structured),
        NutritionNotesFields(
            health: widget.health,
            enabled: widget.enabled,
            onChanged: (key, value) => _change(key, value)),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
            onPressed: widget.enabled ? _save : null,
            child: const Text('Lưu phần thông tin đã cập nhật')),
      ]);
}
