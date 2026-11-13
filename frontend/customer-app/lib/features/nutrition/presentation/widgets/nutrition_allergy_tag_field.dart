import 'nutrition_allergy_tag_input.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

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
    _commitDraft(value);
  }

  void _commitDraft([String? submitted]) {
    final value = (submitted ?? _input.text).trim();
    if (value.isEmpty) return;
    final next = _tagsWithDraft(value);
    if (next.join('; ').length > widget.maxLength) {
      _sync(includeDraft: true);
      return;
    }
    _tags
      ..clear()
      ..addAll(next);
    _input.clear();
    _sync();
  }

  List<String> _tagsWithDraft(String draft) {
    final keys = _tags.map((tag) => tag.toLowerCase()).toSet();
    return [
      ..._tags,
      ..._split(draft).where((tag) => keys.add(tag.toLowerCase()))
    ];
  }

  void _remove(String value) {
    _tags.remove(value);
    _sync(includeDraft: true);
  }

  void _sync({bool includeDraft = false}) {
    final values = includeDraft ? _tagsWithDraft(_input.text) : _tags;
    final serialized = values.join('; ');
    setState(() {
      widget.controller.value = TextEditingValue(
        text: serialized,
        selection: TextSelection.collapsed(offset: serialized.length),
      );
    });
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
    final overflow = currentLength > widget.maxLength;
    final error = overflow
        ? 'Danh sách dị nguyên vượt ${widget.maxLength} ký tự. Vui lòng rút gọn.'
        : widget.errorText;
    final hasError = error != null;
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
          onChanged: _handleInput,
          onSubmitted: _commitDraft,
          onRemove: _remove,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          error ?? 'Nhấn Enter, dấu phẩy hoặc dấu chấm phẩy để thêm thực phẩm.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasError ? AppColors.error : AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
