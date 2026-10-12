import 'package:caregiver_app/features/settings/presentation/models/settings_item.dart';
import 'package:flutter/material.dart';

class SettingsSupportLinks extends StatelessWidget {
  const SettingsSupportLinks(
      {super.key,
      required this.buildSection,
      required this.callbackAction1,
      required this.callbackAction2});
  final Widget Function(
      {required List<SettingsItem> items, required String title}) buildSection;
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => buildSection(
        title: 'Hỗ trợ',
        items: [
          SettingsItem(
            icon: Icons.help_outline_rounded,
            title: 'Câu hỏi thường gặp',
            onTap: callbackAction1,
          ),
          SettingsItem(
            icon: Icons.support_agent_rounded,
            title: 'Trung tâm trợ giúp',
            onTap: callbackAction2,
          ),
        ],
      );
}
