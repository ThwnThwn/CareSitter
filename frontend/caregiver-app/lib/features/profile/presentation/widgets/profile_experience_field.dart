import 'package:flutter/material.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_text_field.dart';

/// Ô nhập số năm kinh nghiệm có validation số nguyên.
class ProfileExperienceField extends StatelessWidget {
  final TextEditingController controller;

  const ProfileExperienceField({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileTextField(
      controller: controller,
      label: 'Số năm kinh nghiệm',
      hint: 'Ví dụ: 3',
      icon: Icons.workspace_premium_outlined,
      keyboardType: TextInputType.number,
      validator: (val) {
        if (val != null && val.isNotEmpty && int.tryParse(val) == null) {
          return 'Vui lòng nhập số nguyên';
        }
        return null;
      },
    );
  }
}
