import 'package:caregiver_app/core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DocumentCertificateChips extends StatelessWidget {
  const DocumentCertificateChips(
      {super.key,
      required this.certificates,
      required this.submitting,
      required this.onRemove});
  final List<XFile> certificates;
  final bool submitting;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: List.generate(certificates.length, (index) {
          return InputChip(
            label: Text('Chứng chỉ ${index + 1}'),
            onDeleted: submitting ? null : () => onRemove(index),
          );
        }),
      );
}
