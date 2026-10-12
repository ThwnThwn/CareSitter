import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_text_field.dart';

/// Row Quận/Huyện và Tỉnh/Thành phố.
class ProfileLocationRow extends StatelessWidget {
  final TextEditingController districtController;
  final TextEditingController cityController;

  const ProfileLocationRow({
    super.key,
    required this.districtController,
    required this.cityController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ProfileTextField(
            controller: districtController,
            label: 'Quận/Huyện',
            hint: 'Ví dụ: Quận 5',
            icon: Icons.location_city_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.compact),
        Expanded(
          child: ProfileTextField(
            controller: cityController,
            label: 'Tỉnh/Thành phố',
            hint: 'Ví dụ: TP.HCM',
            icon: Icons.map_outlined,
          ),
        ),
      ],
    );
  }
}
