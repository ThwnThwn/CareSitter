import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/widgets/beneficiary_avatar_image.dart';

class BeneficiaryEditAvatar extends StatelessWidget {
  const BeneficiaryEditAvatar(
      {super.key, required this.avatarPath, required this.pickImage});
  final String? avatarPath;
  final Future<void> Function() pickImage;
  @override
  Widget build(BuildContext context) => Center(
        child: Stack(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2.5),
                image: avatarPath != null && avatarPath!.isNotEmpty
                    ? DecorationImage(
                        image: beneficiaryAvatarImageProvider(avatarPath!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarPath != null && avatarPath!.isNotEmpty
                  ? null
                  : const Center(
                      child: Icon(Icons.person,
                          size: 40, color: AppColors.primary),
                    ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: pickImage,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.tight),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
      );
}
