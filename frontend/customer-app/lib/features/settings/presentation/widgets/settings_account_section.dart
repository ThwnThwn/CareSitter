import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'settings_section.dart';
import 'settings_settings_item.dart';

/// Section "Tài khoản" theo Stitch:
/// Gồm Thông tin cá nhân, Cài đặt thông báo, Ví CareSitter và Địa chỉ đã lưu.
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
            onTap: () => context.push(AppRoutes.profileEdit),
          ),
          SettingsSettingsItem(
            icon: Icons.notifications_outlined,
            iconBackgroundColor: const Color(0xFFE6FFFA), // teal-50
            iconColor: const Color(0xFF0F766E),
            title: 'Cài đặt thông báo',
            subtitle: 'Lịch hẹn, thanh toán và cập nhật dịch vụ',
            onTap: () => context.push(AppRoutes.notificationSettings),
          ),
          SettingsSettingsItem(
            icon: Icons.account_balance_wallet_outlined,
            iconBackgroundColor: const Color(0xFFE8F7F0), // emerald-50
            iconColor: AppColors.primary,
            title: 'Ví CareSitter',
            subtitle: 'Số dư ví và lịch sử hoàn tiền',
            onTap: () => context.push(AppRoutes.wallet),
          ),
          SettingsSettingsItem(
            icon: Icons.location_on_outlined,
            iconBackgroundColor: const Color(0xFFF1F5F9), // slate-100
            iconColor: const Color(0xFF475569), // slate-600
            title: 'Địa chỉ đã lưu',
            subtitle: 'Địa chỉ nhận dịch vụ chăm sóc tại nhà',
            showDivider: false,
            onTap: () => context.push(AppRoutes.addresses),
          ),
        ],
      ),
    );
  }
}
