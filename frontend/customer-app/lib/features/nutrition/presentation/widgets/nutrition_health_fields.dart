import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_dropdown_field.dart';
import 'package:flutter/material.dart';

import '../models/nutrition_medication_draft.dart';
import 'nutrition_expansion_card.dart';
import 'nutrition_medication_editor.dart';

/// Edits only the structured fields supplied by the customer; saved history stays on People.
class NutritionHealthFields extends StatefulWidget {
  final Map<String, dynamic> health;
  final bool enabled;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const NutritionHealthFields(
      {super.key,
      required this.health,
      required this.enabled,
      required this.onChanged,
      this.showErrors = false,
      this.missingFields = const []});
  final bool showErrors;
  final List<String> missingFields;

  @override
  State<NutritionHealthFields> createState() => NutritionHealthFieldsState();
}

class NutritionHealthFieldsState extends State<NutritionHealthFields>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final Map<String, dynamic> _profileChanges = {};
  final ExpansibleController _expansion = ExpansibleController();
  late final Map<String, dynamic> _profile;
  final List<NutritionMedicationDraft> _medications = [];
  final Map<String, GlobalKey> _fieldKeys = {
    'medicationsStatus': GlobalKey(),
    'feedingRoute': GlobalKey(),
    'swallowingStatus': GlobalKey(),
    'fluidRestriction': GlobalKey(),
    'electrolyteRestriction': GlobalKey(),
  };
  bool _medicationsDirty = false, _legacyMedications = false;

  @override
  void didUpdateWidget(covariant NutritionHealthFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.showErrors && !oldWidget.showErrors) ||
        !_sameMissingFields(oldWidget.missingFields, widget.missingFields)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasAnyError && !_expansion.isExpanded) {
          _expansion.expand();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final history = widget.health['healthHistory'];
    _profile = history is Map && history['nutrition'] is Map
        ? Map<String, dynamic>.from(history['nutrition'])
        : {};
    final raw = widget.health['medications'];
    if (raw != null) {
      if (raw is List && raw.every((m) => m is Map && m['name'] is String)) {
        _medications.addAll(raw.map((m) =>
            NutritionMedicationDraft(Map<String, dynamic>.from(m as Map))));
      } else {
        _legacyMedications = true;
      }
    }
    if (_hasAnyError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_expansion.isExpanded) _expansion.expand();
      });
    }
  }

  bool _sameMissingFields(List<String> before, List<String> after) =>
      before.length == after.length &&
      before.asMap().entries.every((entry) => entry.value == after[entry.key]);

  bool _isMissing(String field) => widget.missingFields.any((item) {
        if (item == field || item.endsWith('/$field')) return true;
        return field == 'medicationsStatus' &&
            (item == 'medications' || item.startsWith('medications/'));
      });

  bool _isLocallyInvalid(String field) {
    final current = _profileChanges[field] ?? _profile[field];
    if (current == null || current == 'unknown') return true;
    if (field != 'medicationsStatus') return false;
    final hasMedication =
        _medications.any((item) => item.name.text.trim().isNotEmpty) ||
            _legacyMedications;
    return (current == 'reported_present' && !hasMedication) ||
        (current == 'reported_none' && hasMedication);
  }

  bool get _hasAnyError => _fieldKeys.keys.any(
        (field) =>
            _isMissing(field) ||
            (widget.showErrors && _isLocallyInvalid(field)),
      );

  Future<void> revealFirstError() async {
    final field = _fieldKeys.keys.cast<String?>().firstWhere(
          (item) =>
              item != null &&
              (_isMissing(item) ||
                  (widget.showErrors && _isLocallyInvalid(item))),
          orElse: () => null,
        );
    if (field == null) return;
    if (!_expansion.isExpanded) _expansion.expand();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final target = _fieldKeys[field]?.currentContext;
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      alignment: 0.18,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _emit() => widget.onChanged({
        if (_profileChanges.isNotEmpty)
          'nutritionProfile': Map<String, dynamic>.from(_profileChanges),
        if (_medicationsDirty)
          'medications': _medications.map((m) => m.value()).toList(),
      });

  Widget _choice(String field, String label, Map<String, String> options) {
    final current = _profileChanges[field] ?? _profile[field];
    final hasMedication =
        _medications.any((m) => m.name.text.trim().isNotEmpty) ||
            _legacyMedications;
    final medicationConflict = field == 'medicationsStatus' &&
        ((current == 'reported_present' && !hasMedication) ||
            (current == 'reported_none' && hasMedication));
    return Padding(
      key: _fieldKeys[field],
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppDropdownField<String>(
        key: ValueKey('nutrition-$field'),
        initialValue:
            options.containsKey(current) ? current as String : 'unknown',
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label,
            errorText: _isMissing(field) ||
                    (widget.showErrors &&
                        (current == null ||
                            current == 'unknown' ||
                            medicationConflict))
                ? (medicationConflict
                    ? 'Vui lòng làm rõ danh sách thuốc'
                    : _isMissing(field)
                        ? 'Vui lòng kiểm tra lại mục này'
                        : 'Vui lòng xác nhận mục này')
                : null),
        items: options.entries
            .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value,
                    maxLines: 1, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: !widget.enabled
            ? null
            : (v) {
                setState(() => _profileChanges[field] = v);
                _emit();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NutritionExpansionCard(
      key: const ValueKey('nutrition-structured-fields'),
      controller: _expansion,
      title: 'Thuốc và nhu cầu ăn uống',
      subtitle: 'Xác nhận từng mục; chọn Chưa rõ nếu chưa có thông tin.',
      children: [
        const SizedBox(height: AppSpacing.compact),
        _choice('medicationsStatus', 'Việc dùng thuốc hiện tại', const {
          'unknown': 'Chưa rõ',
          'reported_none': 'Đã xác nhận không dùng',
          'reported_present': 'Đang dùng thuốc',
        }),
        if (_legacyMedications)
          const Text(
              'Danh sách thuốc cũ chưa đúng định dạng. Thông tin được giữ nguyên và cần kiểm tra lại trong hồ sơ.'),
        for (var i = 0; i < _medications.length; i++)
          _medication(_medications[i], i),
        if (!_legacyMedications && _medications.length < 40)
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Thêm thuốc đã được kê / đang dùng'),
                onPressed: !widget.enabled
                    ? null
                    : () {
                        setState(() {
                          _medications.add(NutritionMedicationDraft(
                              {'name': '', 'is_active': true}));
                          _medicationsDirty = true;
                        });
                        _emit();
                      },
              )),
        const SizedBox(height: AppSpacing.compact),
        _choice('feedingRoute', 'Cách ăn uống hiện tại', const {
          'unknown': 'Chưa rõ',
          'oral': 'Ăn uống qua miệng',
          'tube': 'Ăn qua ống',
        }),
        _choice('swallowingStatus', 'Khả năng nuốt', const {
          'unknown': 'Chưa rõ',
          'normal': 'Không có khó khăn đã biết',
          'difficulty': 'Có khó khăn khi nuốt',
        }),
        _choice('fluidRestriction', 'Hướng dẫn hạn chế nước', const {
          'unknown': 'Chưa rõ',
          'none': 'Đã xác nhận không có',
          'present': 'Có hướng dẫn hạn chế',
        }),
        _choice('electrolyteRestriction', 'Hướng dẫn về điện giải', const {
          'unknown': 'Chưa rõ',
          'none': 'Đã xác nhận không có',
          'present': 'Có hướng dẫn riêng',
        }),
      ],
    );
  }

  Widget _medication(NutritionMedicationDraft medication, int index) =>
      NutritionMedicationEditor(
        key: ObjectKey(medication),
        medication: medication,
        index: index,
        enabled: widget.enabled,
        onNameChanged: () {
          setState(() => _medicationsDirty = true);
          _emit();
        },
        onChanged: () {
          _medicationsDirty = true;
          _emit();
        },
        onRemove: () {
          setState(() {
            _medications.remove(medication);
            _medicationsDirty = true;
          });
          medication.dispose();
          _emit();
        },
      );

  @override
  void dispose() {
    _expansion.dispose();
    for (final medication in _medications) {
      medication.dispose();
    }
    super.dispose();
  }
}
