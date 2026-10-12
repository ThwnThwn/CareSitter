import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class ProfileEditForm extends StatelessWidget {
  const ProfileEditForm(
      {super.key,
      required this.formKey,
      required this.pendingAvatarFile,
      required this.profile,
      required this.buildInitials,
      required this.nameCtrl,
      required this.isUploadingAvatar,
      required this.ref,
      required this.pickAvatar,
      required this.buildSectionHeader,
      required this.displayNameCtrl,
      required this.emailCtrl,
      required this.dobCtrl,
      required this.selectDate,
      required this.gender,
      required this.saveProfile,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.callbackAction5});
  final GlobalKey<FormState> formKey;
  final XFile? pendingAvatarFile;
  final UserProfile profile;
  final String Function(String) buildInitials;
  final TextEditingController nameCtrl;
  final bool isUploadingAvatar;
  final WidgetRef ref;
  final Future<void> Function() pickAvatar;
  final Widget Function(String) buildSectionHeader;
  final TextEditingController displayNameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController dobCtrl;
  final Future<void> Function() selectDate;
  final String gender;
  final Future<void> Function() saveProfile;
  final void Function(String) callbackAction1;
  final String? Function(String?) callbackAction2;
  final void Function() callbackAction3;
  final String? Function(String?) callbackAction4;
  final void Function(String?) callbackAction5;

  @override
  Widget build(BuildContext context) => Form(
        key: formKey,
        child: ProfileEditFields(
            pendingAvatarFile: pendingAvatarFile,
            profile: profile,
            buildInitials: buildInitials,
            nameCtrl: nameCtrl,
            isUploadingAvatar: isUploadingAvatar,
            ref: ref,
            pickAvatar: pickAvatar,
            buildSectionHeader: buildSectionHeader,
            callbackAction1: callbackAction1,
            callbackAction2: callbackAction2,
            displayNameCtrl: displayNameCtrl,
            emailCtrl: emailCtrl,
            callbackAction3: callbackAction3,
            callbackAction4: callbackAction4,
            dobCtrl: dobCtrl,
            selectDate: selectDate,
            gender: gender,
            callbackAction5: callbackAction5,
            saveProfile: saveProfile),
      );
}
