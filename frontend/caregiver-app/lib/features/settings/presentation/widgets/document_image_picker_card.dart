import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class DocumentImagePickerCard extends StatelessWidget {
  final String label;
  final XFile? file;
  final VoidCallback onTap;

  const DocumentImagePickerCard(
      {super.key,
      required this.label,
      required this.file,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(AppSpacing.compact),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: file == null ? AppColors.border : AppColors.primary),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(file == null ? Icons.add_a_photo_outlined : Icons.check_circle,
                color: file == null ? AppColors.textHint : AppColors.primary,
                size: 36),
            const SizedBox(height: AppSpacing.control),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.xs),
            Text(file == null ? 'Chạm để chọn ảnh' : file!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.s11)),
          ],
        ),
      ),
    );
  }
}
