import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingScreenFamilyNote extends StatelessWidget {
  const ShiftTrackingScreenFamilyNote({super.key, required this.note});
  final String note;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.inset),
      decoration: BoxDecoration(
        color: AppColors.goldSurface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.goldBorder, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_outlined,
              color: AppColors.gold, size: 18),
          const SizedBox(width: AppSpacing.control),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ghi chú của gia đình',
                    style: TextStyle(
                        fontSize: AppFontSizes.s11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldDark)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  note,
                  style: const TextStyle(
                      fontSize: AppFontSizes.s13,
                      color: AppColors.textPrimary,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
