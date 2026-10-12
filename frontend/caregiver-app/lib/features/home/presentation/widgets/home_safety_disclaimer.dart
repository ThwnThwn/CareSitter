import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeSafetyDisclaimer extends StatelessWidget {
  const HomeSafetyDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.inset),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.tertiary, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety_rounded,
              color: AppColors.tertiary, size: 22),
          const SizedBox(width: AppSpacing.control),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cam kết an toàn & phi y tế',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: AppFontSizes.s18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.beVietnamPro(
                      fontSize: AppFontSizes.s12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                          text:
                              'Lưu ý: Luôn tuân thủ quy tắc hỗ trợ phi y tế. Tuyệt đối không can thiệp nghiệp vụ y khoa. '),
                      TextSpan(
                        text: 'Gọi ngay 115',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: AppFontSizes.s12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                      const TextSpan(
                          text: ' khi xảy ra sự cố sức khỏe đột xuất.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
