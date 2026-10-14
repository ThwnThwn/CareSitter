import 'package:go_router/go_router.dart';
import 'settings_section.dart';
import 'package:caregiver_app/features/settings/presentation/models/settings_item.dart';
import 'package:flutter/material.dart';

class SettingsProfileLinks extends StatelessWidget {
  const SettingsProfileLinks({super.key});

  @override
  Widget build(BuildContext context) => SettingsSection(
        title: 'Cài đặt hồ sơ',
        items: [
          SettingsItem(
            icon: Icons.mark_email_read_outlined,
            title: 'Email khôi phục',
            subtitle: 'Xác minh hoặc đổi email đăng nhập',
            onTap: () => context.push('/settings/recovery-email'),
          ),
          SettingsItem(
            icon: Icons.person_outline,
            title: 'Thông tin cá nhân',
            onTap: () => context.push('/settings/profile/edit'),
          ),
          SettingsItem(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Thu nhập & ví',
            subtitle: 'Xem số dư, lịch sử và yêu cầu rút tiền',
            onTap: () => context.push('/earnings'),
          ),
          SettingsItem(
            icon: Icons.badge_outlined,
            title: 'Hồ sơ & Giấy tờ',
            subtitle: 'Thông tin KYC và tài liệu đã nộp',
            onTap: () => context.push('/settings/documents'),
          ),
          SettingsItem(
            icon: Icons.star_outline_rounded,
            title: 'Đánh giá & Nhận xét',
            onTap: () => context.push('/settings/reviews'),
          ),
        ],
      );
}
