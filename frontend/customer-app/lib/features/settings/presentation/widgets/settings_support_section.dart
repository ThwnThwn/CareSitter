import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/auth_session_controller.dart';
import 'settings_section.dart';
import 'settings_settings_item.dart';

/// Section "Hỗ trợ & Điều khoản" theo Stitch:
/// Gồm Trung tâm trợ giúp, Chính sách & điều khoản, và Đăng xuất tài khoản (nhánh màu đỏ).
class SettingsSupportSection extends ConsumerWidget {
  const SettingsSupportSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: 'Hỗ trợ & Điều khoản',
      items: [
        SettingsSettingsItem(
          icon: Icons.headset_mic_outlined,
          iconBackgroundColor: const Color(0xFFEFF6FF), // blue-50
          iconColor: const Color(0xFF2563EB), // blue-600
          title: 'Trung tâm trợ giúp & CSKH',
          subtitle: 'Câu hỏi thường gặp và hỗ trợ 24/7',
          onTap: () => context.push(AppRoutes.faq),
        ),
        SettingsSettingsItem(
          icon: Icons.verified_user_outlined,
          iconBackgroundColor: const Color(0xFFF1F5F9), // slate-100
          iconColor: const Color(0xFF475569), // slate-600
          title: 'Chính sách & Điều khoản CareSitter',
          subtitle: 'Quy định dịch vụ & bảo vệ quyền lợi',
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'CareSitter',
          ),
        ),
        SettingsSettingsItem(
          icon: Icons.logout_rounded,
          iconBackgroundColor: const Color(0xFFFFF1F2), // rose-50
          iconColor: const Color(0xFFE11D48), // rose-600
          title: 'Đăng xuất tài khoản',
          titleColor: const Color(0xFFE11D48),
          showDivider: false,
          onTap: () => _confirmLogout(context, ref),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authSessionControllerProvider).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(90, 40),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}
