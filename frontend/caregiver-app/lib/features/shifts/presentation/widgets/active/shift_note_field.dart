import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';

class ShiftNoteField extends ConsumerStatefulWidget {
  const ShiftNoteField({
    super.key,
    required this.bookingId,
    required this.enabled,
  });

  final String bookingId;
  final bool enabled;

  @override
  ConsumerState<ShiftNoteField> createState() => _ShiftNoteFieldState();
}

class _ShiftNoteFieldState extends ConsumerState<ShiftNoteField> {
  static const _suggestions = [
    'Bác ăn ngon miệng',
    'Tâm trạng vui vẻ',
    'Nghỉ ngơi đúng giờ',
  ];

  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: ref.read(shiftActiveProvider(widget.bookingId)).note,
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _addSuggestion(String suggestion) {
    if (!widget.enabled) return;
    final current = _text.text.trim();
    final separator = current.isEmpty || current.endsWith('.') ? ' ' : '. ';
    final next = current.isEmpty ? suggestion : '$current$separator$suggestion';
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    ref.read(shiftActiveProvider(widget.bookingId).notifier).setNote(next);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.edit_note_rounded, color: AppColors.primary),
              Text(
                'Ghi chú ca trực',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Gửi cho gia đình',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Container(
            padding: const EdgeInsets.all(AppSpacing.compact),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _text,
                  enabled: widget.enabled,
                  minLines: 3,
                  maxLines: 5,
                  onChanged: ref
                      .read(shiftActiveProvider(widget.bookingId).notifier)
                      .setNote,
                  decoration: const InputDecoration(
                    hintText:
                        'Nhập lưu ý hoặc phản hồi quan trọng gửi gia đình sau ca…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Gợi ý nhanh',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.s12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final suggestion in _suggestions)
                      ActionChip(
                        onPressed: widget.enabled
                            ? () => _addSuggestion(suggestion)
                            : null,
                        label: Text('+ $suggestion'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}
