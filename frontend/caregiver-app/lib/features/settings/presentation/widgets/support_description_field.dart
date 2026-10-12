import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class SupportDescriptionField extends StatelessWidget {
  const SupportDescriptionField(
      {super.key, required this.descController, required this.callbackAction1});
  final TextEditingController descController;
  final String? Function(String?) callbackAction1;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: descController,
        maxLines: 4,
        validator: callbackAction1,
        decoration: InputDecoration(
          labelText: 'Mô tả chi tiết',
          hintText:
              'Mô tả sự cố bạn đang gặp phải và cung cấp thêm thông tin nếu có...',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
        ),
      );
}
