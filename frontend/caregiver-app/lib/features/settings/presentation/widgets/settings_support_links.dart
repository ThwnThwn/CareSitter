import 'package:go_router/go_router.dart';
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
        ],
      );
}
