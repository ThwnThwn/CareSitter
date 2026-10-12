import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class DisputeAttachmentsPickImageRow extends StatelessWidget {
  const DisputeAttachmentsPickImageRow(
      {super.key,
      required this.attachments,
      required this.pickImage,
      required this.pickVideo});
  final List<XFile> attachments;
  final Future<void> Function() pickImage;
  final Future<void> Function() pickVideo;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          OutlinedButton.icon(
            onPressed: attachments.length < 5 ? pickImage : null,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('Ảnh'),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: attachments.length < 5 ? pickVideo : null,
            icon: const Icon(Icons.videocam_outlined, size: 18),
            label: const Text('Video'),
          ),
        ],
      );
}
