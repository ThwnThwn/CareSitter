import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ProfileAvatarPicker {
  const ProfileAvatarPicker._();
  static Future<XFile?> pick({required bool Function() isActive}) async {
    final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85);
    if (image == null || !isActive()) return null;
    if (kIsWeb) return image;
    try {
      final cropped = await ImageCropper().cropImage(
          sourcePath: image.path,
          compressQuality: 85,
          maxWidth: 1024,
          maxHeight: 1024,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
                toolbarTitle: 'Chỉnh ảnh đại diện',
                toolbarColor: AppColors.primary,
                toolbarWidgetColor: Colors.white,
                lockAspectRatio: true),
            IOSUiSettings(
                title: 'Chỉnh ảnh đại diện',
                doneButtonTitle: 'Xong',
                cancelButtonTitle: 'Hủy',
                aspectRatioLockEnabled: true),
          ]);
      return !isActive() || cropped == null ? null : XFile(cropped.path);
    } catch (_) {
      return isActive() ? image : null;
    }
  }
}
