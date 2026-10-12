import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class NotificationSettingsInset extends StatelessWidget {
  const NotificationSettingsInset({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Text(
          'Thay đổi được tự động lưu. Bạn vẫn có thể nhận thông báo hệ thống bắt buộc (OTP, bảo mật).',
          style: TextStyle(
              fontSize: AppFontSizes.s12,
              color: AppColors.textSecondary,
              height: 1.5),
        ),
      );
}
