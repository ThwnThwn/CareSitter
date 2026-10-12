import 'package:image_picker/image_picker.dart';

class GalleryImagePicker {
  const GalleryImagePicker._();
  static Future<XFile?> pick({double maxWidth = 500, double maxHeight = 500}) =>
      ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: 85);
}
