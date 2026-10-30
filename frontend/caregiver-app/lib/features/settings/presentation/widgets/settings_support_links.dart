import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/config/legal_links.dart';
import 'settings_section.dart';
import 'package:caregiver_app/features/settings/presentation/models/settings_item.dart';
import 'package:flutter/material.dart';

class SettingsSupportLinks extends StatelessWidget {
  const SettingsSupportLinks({super.key});

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Hỗ trợ',
        items: [
          SettingsItem(
            icon: Icons.help_outline_rounded,
            title: 'Câu hỏi thường gặp',
            onTap: () => context.push('/settings/faq'),
          ),
          SettingsItem(
            icon: Icons.support_agent_rounded,
            title: 'Trung tâm trợ giúp',
            onTap: () => context.push('/settings/support'),
          ),
          SettingsItem(
            icon: Icons.verified_user_outlined,
            title: 'Chính sách quyền riêng tư',
            subtitle: 'Cách CareSitter xử lý và bảo vệ dữ liệu',
            onTap: () => _openLegal(context, LegalLinks.openPrivacy),
          ),
          SettingsItem(
            icon: Icons.description_outlined,
            title: 'Điều khoản dịch vụ',
            subtitle: 'Quyền, trách nhiệm và quy tắc nội dung',
            onTap: () => _openLegal(context, LegalLinks.openTerms),
          ),
          SettingsItem(
            icon: Icons.person_remove_outlined,
            title: 'Xóa tài khoản',
            subtitle: 'Gửi yêu cầu xóa tài khoản và dữ liệu',
            onTap: () => _openLegal(context, LegalLinks.openAccountDeletion),
          ),
        ],
      );

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
}
