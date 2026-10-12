import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_avatar_editor.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_gender_dob_row.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_skills_editor.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_location_row.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_section_title.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_basic_info_section.dart';
import 'package:caregiver_app/features/profile/presentation/widgets/profile_experience_field.dart';

class ProfileEditForm extends StatelessWidget {
  const ProfileEditForm(
      {super.key,
      required this.formKey,
      required this.profile,
      required this.isUploadingAvatar,
      required this.pickAndUploadAvatar,
      required this.nameController,
      required this.bioController,
      required this.gender,
      required this.dobController,
      required this.selectDateOfBirth,
      required this.districtController,
      required this.cityController,
      required this.expController,
      required this.skills,
      required this.skillInputController,
      required this.addSkill,
      required this.removeSkill,
      required this.callbackAction1});
  final GlobalKey<FormState> formKey;
  final CaregiverProfileModel profile;
  final bool isUploadingAvatar;
  final Future<void> Function() pickAndUploadAvatar;
  final TextEditingController nameController;
  final TextEditingController bioController;
  final String gender;
  final TextEditingController dobController;
  final Future<void> Function() selectDateOfBirth;
  final TextEditingController districtController;
  final TextEditingController cityController;
  final TextEditingController expController;
  final List<String> skills;
  final TextEditingController skillInputController;
  final void Function() addSkill;
  final void Function(String) removeSkill;
  final void Function(String) callbackAction1;

  @override
  Widget build(BuildContext context) => Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar Editor ──
            Center(
              child: ProfileAvatarEditor(
                avatarUrl: profile.avatarUrl,
                initials: profile.initials,
                isUploading: isUploadingAvatar,
                onTap: pickAndUploadAvatar,
              ),
            ),
            const SizedBox(height: AppSpacing.wide),

            // ── Thông tin cơ bản ──
            const ProfileSectionTitle('Thông tin cơ bản'),
            const SizedBox(height: AppSpacing.compact),
            ProfileBasicInfoSection(
              nameController: nameController,
              bioController: bioController,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Giới tính & Ngày sinh ──
            ProfileGenderDobRow(
              gender: gender,
              dobController: dobController,
              onGenderChanged: callbackAction1,
              onTapDob: selectDateOfBirth,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Khu vực & Kinh nghiệm ──
            const ProfileSectionTitle('Khu vực & Kinh nghiệm'),
            const SizedBox(height: AppSpacing.compact),
            ProfileLocationRow(
              districtController: districtController,
              cityController: cityController,
            ),
            const SizedBox(height: AppSpacing.md),
            ProfileExperienceField(
              controller: expController,
            ),

            // ── Kỹ năng chuyên môn ──
            const ProfileSectionTitle('Kỹ năng chuyên môn'),
            const SizedBox(height: AppSpacing.compact),
            ProfileSkillsEditor(
              skills: skills,
              inputController: skillInputController,
              onAdd: addSkill,
              onRemove: removeSkill,
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
}
