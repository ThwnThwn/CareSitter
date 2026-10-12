import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SupportPanel extends StatelessWidget {
  const SupportPanel({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Column(
          children: [
            Icon(Icons.headset_mic, size: 48, color: Colors.white),
            SizedBox(height: AppSpacing.md),
            Text(
              'CareSitter luôn lắng nghe',
              style: TextStyle(
                color: Colors.white,
                fontSize: AppFontSizes.s18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Chúng tôi hỗ trợ 24/7 để giải quyết mọi thắc mắc của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: AppFontSizes.s14,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
}
