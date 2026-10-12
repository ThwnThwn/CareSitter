import 'package:caregiver_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SupportAttachmentChips extends StatelessWidget {
  const SupportAttachmentChips(
      {super.key,
      required this.attachments,
      required this.submitting,
      required this.onRemove});
  final List<XFile> attachments;
  final bool submitting;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: List.generate(attachments.length, (index) {
          return InputChip(
            label:
                Text(attachments[index].name, overflow: TextOverflow.ellipsis),
            onDeleted: submitting ? null : () => onRemove(index),
          );
        }),
      );
}
