import 'package:caresitter_customer/features/settings/presentation/widgets/settings_settings_item.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'settings_section.dart';

class SettingsAccountSection extends StatelessWidget {
  const SettingsAccountSection({super.key});
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 2,
        child: SettingsSection(title: 'Tài khoản', items: [
          SettingsSettingsItem(
            icon: Icons.person_outline,
            title: 'Thông tin cá nhân',
            subtitle: 'Tên, số điện thoại, ngày sinh',
            onTap: () => context.push('/settings/profile/edit'),
          ),
          SettingsSettingsItem(
            icon: Icons.notifications_outlined,
            title: 'Cài đặt thông báo',
            subtitle: 'Lịch hẹn, thanh toán, nhắc nhở',
            onTap: () => context.push('/settings/notifications'),
          ),
          SettingsSettingsItem(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Ví CareSitter',
            subtitle: 'Số dư và lịch sử hoàn tiền',
            onTap: () => context.push('/wallet'),
          ),
          SettingsSettingsItem(
            icon: Icons.location_on_outlined,
            title: 'Địa chỉ đã lưu',
            subtitle: 'Địa chỉ nhận dịch vụ',
            onTap: () => context.push('/settings/addresses'),
          ),
        ]),
      );
}
