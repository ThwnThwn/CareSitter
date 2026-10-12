import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_text_field.dart';

/// Form fields cho thông tin cơ bản: Họ tên và Giới thiệu bản thân.
class ProfileBasicInfoSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController bioController;

  const ProfileBasicInfoSection({
    super.key,
    required this.nameController,
    required this.bioController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileTextField(
          controller: nameController,
          label: 'Họ và tên',
          hint: 'Nhập họ và tên đầy đủ',
          icon: Icons.person_outline,
          validator: (val) => val == null || val.trim().isEmpty
              ? 'Họ tên không được trống'
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        ProfileTextField(
          controller: bioController,
          label: 'Giới thiệu bản thân',
          hint: 'Tóm tắt kinh nghiệm và phong cách làm việc của bạn',
          icon: Icons.article_outlined,
          maxLines: 3,
        ),
      ],
    );
  }
}
