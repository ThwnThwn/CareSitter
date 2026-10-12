import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.wide, AppSpacing.xxl, AppSpacing.wide, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: AppSpacing.compact),
            const Text(
              'CareSitter • Caregiver',
              style: TextStyle(
                fontSize: AppFontSizes.s26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Ứng dụng dành cho Người Chăm Sóc & Điều Dưỡng',
              style: TextStyle(
                fontSize: AppFontSizes.s13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      );
}
