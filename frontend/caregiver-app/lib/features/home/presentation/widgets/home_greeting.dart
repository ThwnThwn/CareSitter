import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/home/presentation/widgets/status_toggle_pill.dart';

class HomeGreeting extends StatelessWidget {
  const HomeGreeting(
      {super.key, required this.greetingName, required this.profile});
  final String greetingName;
  final CaregiverProfileModel profile;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    'Chào, $greetingName!',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: AppFontSizes.s18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.verified_rounded,
                    color: AppColors.secondary, size: 17),
              ],
            ),
            const SizedBox(height: AppSpacing.micro),
            StatusTogglePill(profile.isAvailable),
          ],
        ),
      );
}
