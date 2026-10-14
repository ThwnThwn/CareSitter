import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'settings_section.dart';
import 'settings_settings_item.dart';

class SettingsSecuritySection extends StatelessWidget {
  const SettingsSecuritySection({super.key});

  @override
  Widget build(BuildContext context) =>
      SettingsSection(title: 'Bảo mật', items: [
        SettingsSettingsItem(
          icon: Icons.mark_email_read_outlined,
          title: 'Email khôi phục',
          subtitle: 'Xác minh hoặc đổi email đăng nhập',
          onTap: () => context.push('/settings/recovery-email'),
        ),
        SettingsSettingsItem(
          icon: Icons.lock_outline,
          title: 'Đổi mật khẩu',
          onTap: () => context.push('/settings/password'),
        ),
      ]);
}
