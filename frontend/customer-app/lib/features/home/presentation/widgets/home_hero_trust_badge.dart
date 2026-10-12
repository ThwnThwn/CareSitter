import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeHeroTrustBadge extends StatelessWidget {
  const HomeHeroTrustBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.compact, vertical: AppSpacing.tight),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⭐', style: TextStyle(fontSize: AppFontSizes.s13)),
            SizedBox(width: AppSpacing.tight),
            Flexible(
              child: Text(
                'Đồng hành tin cậy cùng Cha Mẹ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSizes.s12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}
