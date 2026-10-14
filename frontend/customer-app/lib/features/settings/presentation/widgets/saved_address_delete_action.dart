import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SavedAddressDeleteAction extends StatelessWidget {
  const SavedAddressDeleteAction(
      {super.key,
      required this.label,
      required this.blocked,
      required this.deleting,
      required this.onDelete});
  final String label;
  final bool blocked, deleting;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Xóa $label',
        icon: deleting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.delete_outline,
                color: AppColors.textHint, size: 20),
        onPressed: blocked ? null : onDelete,
      );
}
