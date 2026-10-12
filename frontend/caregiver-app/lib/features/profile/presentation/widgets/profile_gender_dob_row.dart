import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_text_field.dart';

/// Row chứa dropdown giới tính và ô chọn ngày sinh.
/// Screen sở hữu _gender và _dobController; widget nhận callback để thay đổi.
class ProfileGenderDobRow extends StatelessWidget {
  final String gender;
  final TextEditingController dobController;
  final ValueChanged<String> onGenderChanged;
  final VoidCallback onTapDob;

  const ProfileGenderDobRow({
    super.key,
    required this.gender,
    required this.dobController,
    required this.onGenderChanged,
    required this.onTapDob,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue:
                ['MALE', 'FEMALE', 'OTHER', 'UNSPECIFIED'].contains(gender)
                    ? gender
                    : 'UNSPECIFIED',
            decoration: InputDecoration(
              labelText: 'Giới tính',
              prefixIcon:
                  const Icon(Icons.transgender, color: AppColors.textSecondary),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            items: const [
              DropdownMenuItem(value: 'MALE', child: Text('Nam')),
              DropdownMenuItem(value: 'FEMALE', child: Text('Nữ')),
              DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
              DropdownMenuItem(value: 'UNSPECIFIED', child: Text('Chưa rõ')),
            ],
            onChanged: (val) {
              if (val != null) onGenderChanged(val);
            },
          ),
        ),
        const SizedBox(width: AppSpacing.compact),
        Expanded(
          child: GestureDetector(
            onTap: onTapDob,
            child: AbsorbPointer(
              child: ProfileTextField(
                controller: dobController,
                label: 'Ngày sinh',
                hint: 'YYYY-MM-DD',
                icon: Icons.calendar_today_outlined,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
