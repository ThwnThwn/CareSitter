import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionPreferenceTagField extends StatefulWidget {
  const NutritionPreferenceTagField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.helperText,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.maxLength = 800,
  });

  final Key fieldKey;
  final String label;
  final String helperText;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final int maxLength;

  @override
  State<NutritionPreferenceTagField> createState() =>
      _NutritionPreferenceTagFieldState();
}

class _NutritionPreferenceTagFieldState
    extends State<NutritionPreferenceTagField> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late final List<String> _tags;

  @override
  void initState() {
    super.initState();
    _tags = _split(widget.value);
    _focus.addListener(_commitWhenFocusLeaves);
  }

  List<String> _split(String value) => value
      .split(RegExp(r'[;,\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  void _commitWhenFocusLeaves() {
    if (!_focus.hasFocus) _commit();
  }

  void _onInputChanged(String value) {
    if (RegExp(r'[;,\n]').hasMatch(value)) _commit(value);
  }

  void _commit([String? submitted]) {
    final draft = (submitted ?? _input.text).trim();
    if (draft.isEmpty) return;
    final next = _withDraft(draft);
    if (next.join('; ').length > widget.maxLength) return;
    setState(() {
      _tags
        ..clear()
        ..addAll(next);
      _input.clear();
    });
    widget.onChanged(_tags.join('; '));
  }

  List<String> _withDraft(String draft) {
    final keys = _tags.map((tag) => tag.toLowerCase()).toSet();
    return [
      ..._tags,
      ..._split(draft).where((tag) => keys.add(tag.toLowerCase())),
    ];
  }

  void _remove(String tag) {
    setState(() => _tags.remove(tag));
    widget.onChanged(_tags.join('; '));
  }

  @override
  void dispose() {
    _focus.removeListener(_commitWhenFocusLeaves);
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        key: widget.fieldKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compact,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              color: AppInputStyle.fillColor,
              borderRadius: AppInputStyle.radius,
            ),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in _tags)
                  InputChip(
                    label: Text(tag),
                    onDeleted: widget.enabled ? () => _remove(tag) : null,
                    deleteButtonTooltipMessage: 'Xóa $tag',
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    backgroundColor: AppColors.primaryContainer,
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 170),
                  child: IntrinsicWidth(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      textInputAction: TextInputAction.done,
                      onChanged: _onInputChanged,
                      onSubmitted: _commit,
                      decoration: const InputDecoration(
                        hintText: 'Nhập rồi nhấn Enter...',
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.helperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      );
}
