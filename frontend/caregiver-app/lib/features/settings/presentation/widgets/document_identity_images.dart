import 'package:caregiver_app/features/settings/presentation/widgets/document_image_picker_card.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class DocumentIdentityImages extends StatelessWidget {
  const DocumentIdentityImages(
      {super.key,
      required this.front,
      required this.back,
      required this.callbackAction1,
      required this.callbackAction2});
  final XFile? front;
  final XFile? back;
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: DocumentImagePickerCard(
              label: 'Mặt trước CCCD',
              file: front,
              onTap: callbackAction1,
            ),
          ),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: DocumentImagePickerCard(
              label: 'Mặt sau CCCD',
              file: back,
              onTap: callbackAction2,
            ),
          ),
        ],
      );
}
