import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class PhoneLoginBrand extends StatelessWidget {
  const PhoneLoginBrand({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.wide, 60, AppSpacing.wide, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'CareSitter',
              style: TextStyle(
                fontSize: AppFontSizes.s32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Chăm sóc người thân, trao gửi yêu thương',
              style: TextStyle(
                fontSize: AppFontSizes.s14,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      );
}
