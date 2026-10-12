import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_active_controller.dart';

class ShiftNoteField extends ConsumerStatefulWidget {
  const ShiftNoteField(
      {super.key, required this.bookingId, required this.enabled});
  final String bookingId;
  final bool enabled;
  @override
  ConsumerState<ShiftNoteField> createState() => _ShiftNoteFieldState();
}

class _ShiftNoteFieldState extends ConsumerState<ShiftNoteField> {
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
        text: ref.read(shiftActiveProvider(widget.bookingId)).note);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ghi chú cuối ca', style: Theme.of(context).textTheme.titleMedium),
        const Text('Ghi chú sẽ hiện trong báo cáo gửi khách hàng'),
        const SizedBox(height: AppSpacing.control),
        TextField(
            controller: _text,
            enabled: widget.enabled,
            maxLines: 3,
            onChanged: ref
                .read(shiftActiveProvider(widget.bookingId).notifier)
                .setNote,
            decoration: const InputDecoration(
                hintText: 'Ví dụ: Bé ăn được 1 bát cháo, ngủ trưa 1 tiếng…',
                border: OutlineInputBorder())),
      ]);
}
