import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'settings_section.dart';
import 'settings_settings_item.dart';

/// Section "Tài khoản" theo Stitch:
/// Gồm Thông tin cá nhân, Cài đặt thông báo, Ví CareSitter (kèm badge số dư) và Địa chỉ đã lưu.
class SettingsAccountSection extends StatelessWidget {
  const SettingsAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FadeSlideStaggered(
      index: 2,
      child: SettingsSection(
        title: 'Tài khoản',
        items: [
          SettingsSettingsItem(
            icon: Icons.person_outline,
            iconBackgroundColor: const Color(0xFFE8F7F0), // emerald-50
            iconColor: AppColors.primary,
            title: 'Thông tin cá nhân',
            subtitle: 'Tên, số điện thoại, ngày sinh',
            onTap: () => context.push('/settings/profile/edit'),
          ),
          SettingsSettingsItem(
            icon: Icons.notifications_outlined,
            iconBackgroundColor: const Color(0xFFE6FFFA), // teal-50
            iconColor: const Color(0xFF0F766E),
            title: 'Cài đặt thông báo',
            subtitle: 'Lịch hẹn, thanh toán và cập nhật dịch vụ',
            onTap: () => context.push('/settings/notifications'),
          ),
          SettingsSettingsItem(
            icon: Icons.account_balance_wallet_outlined,
            iconBackgroundColor: const Color(0xFFE8F7F0), // emerald-50
            iconColor: AppColors.primary,
            title: 'Ví CareSitter',
            subtitle: 'Số dư ví và lịch sử hoàn tiền',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5), // emerald-100
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '0đ',
                    style: TextStyle(
                      color: Color(0xFF065F46), // emerald-800
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textHint,
                  size: 20,
                ),
              ],
            ),
            onTap: () => context.push('/wallet'),
          ),
          SettingsSettingsItem(
            icon: Icons.location_on_outlined,
            iconBackgroundColor: const Color(0xFFF1F5F9), // slate-100
            iconColor: const Color(0xFF475569), // slate-600
            title: 'Địa chỉ đã lưu',
            subtitle: 'Địa chỉ nhận dịch vụ chăm sóc tại nhà',
            showDivider: false,
            onTap: () => context.push('/settings/addresses'),
          ),
        ],
      ),
    );
  }
}
