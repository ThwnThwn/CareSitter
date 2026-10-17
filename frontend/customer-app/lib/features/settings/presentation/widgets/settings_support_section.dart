import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'settings_section.dart';
import 'settings_settings_item.dart';

class SettingsSupportSection extends StatelessWidget {
  const SettingsSupportSection({super.key});

  @override
  Widget build(BuildContext context) =>
      SettingsSection(title: 'Hỗ trợ', items: [
        SettingsSettingsItem(
          icon: Icons.help_outline,
          title: 'Câu hỏi thường gặp',
          onTap: () => context.push('/settings/faq'),
        ),
        SettingsSettingsItem(
          icon: Icons.currency_exchange_rounded,
          title: 'Hoàn tiền',
          subtitle: 'Theo dõi trạng thái và lịch sử hoàn tiền',
          onTap: () => context.push('/settings/refunds'),
        ),
        SettingsSettingsItem(
          icon: Icons.headset_mic_outlined,
          title: 'Liên hệ hỗ trợ',
          subtitle: 'Hotline: 1800 6789',
          onTap: () => context.push('/settings/support'),
        ),
        SettingsSettingsItem(
          icon: Icons.info_outline,
          title: 'Giấy phép nguồn mở',
          onTap: () =>
              showLicensePage(context: context, applicationName: 'CareSitter'),
        ),
      ]);
}
