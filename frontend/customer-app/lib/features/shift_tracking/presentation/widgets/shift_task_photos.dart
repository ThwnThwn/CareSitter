import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTaskPhotos extends StatelessWidget {
  const ShiftTaskPhotos(
      {super.key, required this.task, required this.showPhotoPreviewDialog});
  final CareTaskModel task;
  final void Function(BuildContext, String) showPhotoPreviewDialog;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm, left: 38),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: task.photoUrls.map((url) {
                  return GestureDetector(
                    onTap: () => showPhotoPreviewDialog(context, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.network(
                        url,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 50,
                          height: 50,
                          color: AppColors.surface,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 18,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]);
}
