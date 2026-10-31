import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftPhotoPicker {
  const ShiftPhotoPicker();
  Future<XFile?> pick(BuildContext context, ImageSource source) async {
    final picked = await ImagePicker()
        .pickImage(source: source, imageQuality: 82, maxWidth: 1600);
    if (picked == null || !context.mounted) return null;
    return _cropImage(context, picked);
  }

  Future<XFile?> _cropImage(BuildContext context, XFile picked) async {
    final CroppedFile? croppedFile;
    try {
      croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Chỉnh ảnh minh chứng',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.primary,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Chỉnh ảnh minh chứng',
            doneButtonTitle: 'Xong',
            cancelButtonTitle: 'Hủy',
          ),
          WebUiSettings(
            context: context,
            // Trang riêng tránh lỗi layout của cropper dialog ở cửa sổ Web hẹp.
            presentStyle: WebPresentStyle.page,
            dragMode: WebDragMode.move,
            viewwMode: WebViewMode.mode_1,
            checkCrossOrigin: false,
            checkOrientation: false,
            zoomOnWheel: true,
            cropBoxMovable: true,
            cropBoxResizable: true,
          ),
        ],
      );
    } on MissingPluginException {
      return picked;
    }
    if (croppedFile == null) return null;

    return XFile.fromData(
      await croppedFile.readAsBytes(),
      name: croppedFile.path.split(RegExp(r'[/\\]')).last,
    );
  }
}
