import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../data/models/booking_meal_record_model.dart';
import '../models/booking_meal_copy.dart';

class BookingMealEditor extends StatefulWidget {
  const BookingMealEditor({
    super.key,
    required this.mealLabel,
    required this.onSave,
    this.record,
  });
  final String mealLabel;
  final BookingMealRecordModel? record;
  final Future<String?> Function(String outcome, String? note, String? reason)
      onSave;

  @override
  State<BookingMealEditor> createState() => _BookingMealEditorState();
}

class _BookingMealEditorState extends State<BookingMealEditor> {
  final _form = GlobalKey<FormState>();
  late final _note = TextEditingController(text: widget.record?.note);
  final _reason = TextEditingController();
  late String? _outcome = widget.record?.outcome;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || _form.currentState?.validate() != true) return;
    final note = _note.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(_outcome!, note.isEmpty ? null : note,
        widget.record == null ? null : _reason.text.trim());
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final correcting = widget.record != null;
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.compact,
              AppSpacing.md,
              AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(
                            correcting
                                ? 'Đính chính bữa ăn'
                                : 'Ghi nhận bữa ăn',
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(widget.mealLabel),
                const SizedBox(height: AppSpacing.md),
                _MealOutcomeField(
                  value: _outcome,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _outcome = value),
                ),
                const SizedBox(height: AppSpacing.compact),
                TextField(
                  controller: _note,
                  enabled: !_saving,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Lưu ý (nếu có)',
                      border: OutlineInputBorder()),
                ),
                if (correcting)
                  _CorrectionReasonField(
                      controller: _reason, enabled: !_saving),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.error))),
                  ),
                if (_saving)
                  const LinearProgressIndicator(
                      semanticsLabel: 'Đang lưu bữa ăn'),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(correcting ? 'Lưu đính chính' : 'Lưu ghi nhận'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MealOutcomeField extends StatelessWidget {
  const _MealOutcomeField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: mealOutcomeLabels.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: const InputDecoration(
            labelText: 'Kết quả bữa ăn', border: OutlineInputBorder()),
        items: [
          for (final option in mealOutcomeLabels.entries)
            DropdownMenuItem(value: option.key, child: Text(option.value)),
        ],
        validator: (value) => value == null ? 'Chọn kết quả bữa ăn.' : null,
        onChanged: onChanged,
      );
}

class _CorrectionReasonField extends StatelessWidget {
  const _CorrectionReasonField(
      {required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        enabled: enabled,
        maxLength: 500,
        maxLines: 2,
        decoration: const InputDecoration(
            labelText: 'Lý do đính chính', border: OutlineInputBorder()),
        validator: (value) =>
            value?.trim().isNotEmpty == true ? null : 'Nhập lý do đính chính.',
      );
}
