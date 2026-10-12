import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class CatalogScreenBanner extends StatelessWidget {
  const CatalogScreenBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.comfortable, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tư vấn miễn phí',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSizes.s16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Được hỗ trợ chọn dịch vụ phù hợp',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: AppFontSizes.s12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.compact),
                // Call button
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.inset, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Gọi ngay: 1800 6789',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: AppFontSizes.s12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.compact),
          const Text('🏡', style: TextStyle(fontSize: AppFontSizes.s44)),
        ],
      ),
    );
  }
}
