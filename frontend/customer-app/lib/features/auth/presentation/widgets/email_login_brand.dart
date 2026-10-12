import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class EmailLoginBrand extends StatelessWidget {
  const EmailLoginBrand({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.wide, 40, AppSpacing.wide, AppSpacing.wide),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.inset),
            const Text(
              'CareSitter',
              style: TextStyle(
                fontSize: AppFontSizes.s32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.8,
                height: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Đăng nhập nhanh không cần nhớ mật khẩu',
              style: TextStyle(
                fontSize: AppFontSizes.s13,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
}
