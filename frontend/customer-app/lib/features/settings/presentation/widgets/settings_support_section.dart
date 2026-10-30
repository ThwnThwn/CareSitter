import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/config/legal_links.dart';
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
          icon: Icons.chat_bubble_outline,
          iconBackgroundColor: AppColors.primaryContainer,
          iconColor: AppColors.primary,
          title: 'Liên hệ hỗ trợ',
          subtitle: 'Chat và theo dõi phản hồi trong ứng dụng',
          onTap: () => context.push(AppRoutes.support),
        ),
        SettingsSettingsItem(
          icon: Icons.headset_mic_outlined,
          iconBackgroundColor: const Color(0xFFEFF6FF), // blue-50
          iconColor: const Color(0xFF2563EB), // blue-600
          title: 'Câu hỏi thường gặp',
          subtitle: 'Hướng dẫn sử dụng dịch vụ CareSitter',
          onTap: () => context.push(AppRoutes.faq),
        ),
        SettingsSettingsItem(
          icon: Icons.verified_user_outlined,
          iconBackgroundColor: const Color(0xFFF1F5F9), // slate-100
          iconColor: const Color(0xFF475569), // slate-600
          title: 'Chính sách quyền riêng tư',
          subtitle: 'Cách CareSitter xử lý và bảo vệ dữ liệu',
          onTap: () => _openLegal(context, LegalLinks.openPrivacy),
        ),
        SettingsSettingsItem(
          icon: Icons.description_outlined,
          iconBackgroundColor: const Color(0xFFF1F5F9),
          iconColor: const Color(0xFF475569),
          title: 'Điều khoản dịch vụ',
          subtitle: 'Quyền, trách nhiệm và quy tắc nội dung',
          onTap: () => _openLegal(context, LegalLinks.openTerms),
        ),
        SettingsSettingsItem(
          icon: Icons.person_remove_outlined,
          iconBackgroundColor: const Color(0xFFFFF1F2),
          iconColor: const Color(0xFFE11D48),
          title: 'Xóa tài khoản',
          titleColor: const Color(0xFFE11D48),
          subtitle: 'Gửi yêu cầu xóa tài khoản và dữ liệu',
          onTap: () => _openLegal(context, LegalLinks.openAccountDeletion),
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

  Future<void> _openLegal(
    BuildContext context,
    Future<bool> Function() open,
  ) async {
    final opened = await open();
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Chưa cấu hình đường dẫn chính sách. Vui lòng liên hệ hỗ trợ.'),
        ),
      );
    }
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
