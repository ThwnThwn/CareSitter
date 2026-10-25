import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'settings_section.dart';
import 'settings_settings_item.dart';

/// Section "Bảo mật" theo Stitch:
/// Gồm Email khôi phục và Đổi mật khẩu.
class SettingsSecuritySection extends StatelessWidget {
  const SettingsSecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Bảo mật',
      items: [
        SettingsSettingsItem(
          icon: Icons.mark_email_read_outlined,
          iconBackgroundColor: const Color(0xFFEEF2FF), // indigo-50
          iconColor: const Color(0xFF4F46E5), // indigo-600
          title: 'Email khôi phục',
          subtitle: 'Xác minh hoặc đổi email đăng nhập',
          onTap: () => context.push(AppRoutes.recoveryEmail),
        ),
        SettingsSettingsItem(
          icon: Icons.lock_outline,
          iconBackgroundColor: const Color(0xFFF1F5F9), // slate-100
          iconColor: const Color(0xFF475569), // slate-600
          title: 'Đổi mật khẩu',
          subtitle: 'Cập nhật mật khẩu bảo vệ tài khoản',
          showDivider: false,
          onTap: () => context.push(AppRoutes.password),
        ),
      ],
    );
  }
}
