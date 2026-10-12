import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_text_field.dart';

/// Editor danh sách kỹ năng: ô nhập + nút thêm + chip xóa.
/// Screen sở hữu _skills, _skillInputController, _addSkill(), _removeSkill().
class ProfileSkillsEditor extends StatelessWidget {
  final List<String> skills;
  final TextEditingController inputController;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const ProfileSkillsEditor({
    super.key,
    required this.skills,
    required this.inputController,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ProfileTextField(
                controller: inputController,
                label: 'Thêm kỹ năng',
                hint: 'Ví dụ: Chăm sóc người cao tuổi, tiêm insulin...',
                icon: Icons.star_outline_rounded,
              ),
            ),
            const SizedBox(width: AppSpacing.compact),
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: onAdd,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.compact),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: skills.map((skill) {
            return Chip(
              backgroundColor: AppColors.primaryContainer,
              label: Text(
                skill,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              deleteIcon:
                  const Icon(Icons.cancel, size: 16, color: AppColors.primary),
              onDeleted: () => onRemove(skill),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                side: const BorderSide(color: Colors.transparent),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
