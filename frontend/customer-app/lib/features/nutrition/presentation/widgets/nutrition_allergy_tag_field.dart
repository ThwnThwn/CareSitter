import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'nutrition_allergy_tag_input.dart';

class NutritionAllergyTagField extends StatefulWidget {
  const NutritionAllergyTagField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.maxLength,
    required this.onChanged,
    this.errorText,
    this.focusNode,
  });

  final TextEditingController controller;
  final bool enabled;
  final int maxLength;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final FocusNode? focusNode;

  @override
  State<NutritionAllergyTagField> createState() =>
      _NutritionAllergyTagFieldState();
}

class _NutritionAllergyTagFieldState extends State<NutritionAllergyTagField> {
  final TextEditingController _input = TextEditingController();
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  late final List<String> _tags;

  @override
  void initState() {
    super.initState();
    _tags = _split(widget.controller.text);
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_commitWhenFocusLeaves);
  }

  @override
  void didUpdateWidget(covariant NutritionAllergyTagField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    _focusNode.removeListener(_commitWhenFocusLeaves);
    if (_ownsFocusNode) _focusNode.dispose();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_commitWhenFocusLeaves);
  }

  List<String> _split(String value) => value
      .split(RegExp(r'[;,\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();

  void _commitWhenFocusLeaves() {
    if (!_focusNode.hasFocus) _commitDraft();
  }

  void _handleInput(String value) {
    if (!RegExp(r'[;,\n]').hasMatch(value)) {
      _sync(includeDraft: true);
      return;
    }
    final parts = _split(value);
    setState(() {
      for (final part in parts) {
        _addUnique(part);
      }
      _input.clear();
    });
    _sync();
  }

  void _commitDraft([String? submitted]) {
    final value = (submitted ?? _input.text).trim();
    if (value.isEmpty) return;
    setState(() {
      for (final part in _split(value)) {
        _addUnique(part);
      }
      _input.clear();
    });
    _sync();
  }

  void _addUnique(String value) {
    final normalized = value.toLowerCase();
    if (_tags.any((tag) => tag.toLowerCase() == normalized)) return;
    final next = [..._tags, value].join('; ');
    if (next.length <= widget.maxLength) _tags.add(value);
  }

  void _remove(String value) {
    setState(() => _tags.remove(value));
    _sync(includeDraft: true);
  }

  void _sync({bool includeDraft = false}) {
    final values = [..._tags];
    final draft = _input.text.trim();
    if (includeDraft && draft.isNotEmpty) values.add(draft);
    final serialized = values.join('; ');
    widget.controller.value = TextEditingValue(
      text: serialized,
      selection: TextSelection.collapsed(offset: serialized.length),
    );
    widget.onChanged(serialized);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_commitWhenFocusLeaves);
    if (_ownsFocusNode) _focusNode.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = widget.controller.text.length;
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Thực phẩm gây dị ứng *',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: hasError ? AppColors.error : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              '${_tags.length} thẻ ($currentLength/${widget.maxLength})',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        NutritionAllergyTagInput(
          tags: _tags,
          input: _input,
          focusNode: _focusNode,
          enabled: widget.enabled,
          hasError: hasError,
          maxLength: widget.maxLength,
          onChanged: _handleInput,
          onSubmitted: _commitDraft,
          onRemove: _remove,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.errorText ??
              'Nhấn Enter, dấu phẩy hoặc dấu chấm phẩy để thêm thực phẩm.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasError ? AppColors.error : AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
