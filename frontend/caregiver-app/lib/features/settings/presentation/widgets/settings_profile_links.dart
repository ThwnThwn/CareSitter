import 'package:caregiver_app/features/settings/presentation/models/settings_item.dart';
import 'package:flutter/material.dart';

class SettingsProfileLinks extends StatelessWidget {
  const SettingsProfileLinks(
      {super.key,
      required this.buildSection,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.callbackAction5});
  final Widget Function(
      {required List<SettingsItem> items, required String title}) buildSection;
  final void Function() callbackAction1;
  final void Function() callbackAction2;
  final void Function() callbackAction3;
  final void Function() callbackAction4;
  final void Function() callbackAction5;

  @override
  Widget build(BuildContext context) => buildSection(
        title: 'Cài đặt hồ sơ',
        items: [
          SettingsItem(
            icon: Icons.mark_email_read_outlined,
            title: 'Email khôi phục',
            subtitle: 'Xác minh hoặc đổi email đăng nhập',
            onTap: callbackAction1,
          ),
          SettingsItem(
            icon: Icons.person_outline,
            title: 'Thông tin cá nhân',
            onTap: callbackAction2,
          ),
          SettingsItem(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Thu nhập & ví',
            subtitle: 'Xem số dư, lịch sử và yêu cầu rút tiền',
            onTap: callbackAction3,
          ),
          SettingsItem(
            icon: Icons.badge_outlined,
            title: 'Hồ sơ & Giấy tờ',
            subtitle: 'Đã duyệt • Còn hạn',
            onTap: callbackAction4,
          ),
          SettingsItem(
            icon: Icons.star_outline_rounded,
            title: 'Đánh giá & Nhận xét',
            onTap: callbackAction5,
          ),
        ],
      );
}
