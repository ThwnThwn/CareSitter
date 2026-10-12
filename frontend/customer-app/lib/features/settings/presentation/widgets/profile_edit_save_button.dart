import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_edit_controller.dart';

class ProfileEditSaveButton extends StatelessWidget {
  const ProfileEditSaveButton(
      {super.key,
      required this.ref,
      required this.isUploadingAvatar,
      required this.saveProfile});
  final WidgetRef ref;
  final bool isUploadingAvatar;
  final Future<void> Function() saveProfile;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed:
            (ref.watch(profileEditControllerProvider).busy || isUploadingAvatar)
                ? null
                : saveProfile,
        child:
            (ref.watch(profileEditControllerProvider).busy || isUploadingAvatar)
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Lưu thay đổi'),
      );
}
