import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class SupportTitleField extends StatelessWidget {
  const SupportTitleField(
      {super.key,
      required this.titleController,
      required this.callbackAction1});
  final TextEditingController titleController;
  final String? Function(String?) callbackAction1;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: titleController,
        validator: callbackAction1,
        decoration: InputDecoration(
          labelText: 'Tiêu đề vấn đề',
          hintText: 'Ví dụ: Lỗi không check-in được',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
        ),
      );
}
