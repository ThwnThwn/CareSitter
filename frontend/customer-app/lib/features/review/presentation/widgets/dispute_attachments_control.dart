import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class DisputeAttachmentsControl extends StatelessWidget {
  const DisputeAttachmentsControl(
      {super.key, required this.attachments, required this.setState});
  final List<XFile> attachments;
  final void Function(void Function()) setState;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: attachments.length,
          itemBuilder: (ctx, i) {
            final file = attachments[i];
            final isVideo = file.path.endsWith('.mp4') ||
                file.path.endsWith('.mov') ||
                file.path.endsWith('.avi');
            return Container(
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: isVideo
                        ? const Center(
                            child: Icon(Icons.play_circle_fill,
                                size: 32, color: AppColors.primary))
                        : Image.file(File(file.path),
                            width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => attachments.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.micro),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}
