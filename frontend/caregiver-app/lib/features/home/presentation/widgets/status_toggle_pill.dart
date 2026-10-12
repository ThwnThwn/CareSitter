import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/profile/presentation/controllers/profile_controller.dart';

/// Status toggle pill: Rảnh / Bận
class StatusTogglePill extends ConsumerWidget {
  final bool isAvailable;

  const StatusTogglePill(this.isAvailable, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(profileProvider.notifier).toggleAvailability(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.control, vertical: AppSpacing.tiny),
        decoration: BoxDecoration(
          color: isAvailable
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isAvailable
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isAvailable ? AppColors.primary : AppColors.textHint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.tight),
            Text(
              isAvailable ? 'Rảnh ✓' : 'Bận',
              style: GoogleFonts.beVietnamPro(
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w700,
                color: isAvailable ? AppColors.primary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
