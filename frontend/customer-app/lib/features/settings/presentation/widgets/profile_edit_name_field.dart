import '../../domain/settings_input_rules.dart';
import 'package:flutter/material.dart';

class ProfileEditNameField extends StatelessWidget {
  const ProfileEditNameField(
      {super.key, required this.nameCtrl, required this.onNameChanged});
  final TextEditingController nameCtrl;
  final void Function(String) onNameChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: nameCtrl,
        decoration: const InputDecoration(
          labelText: 'Họ và tên *',
          prefixIcon: Icon(Icons.person_outline),
        ),
        onChanged: onNameChanged, // cập nhật initials realtime
        validator: SettingsInputRules.profileName,
      );
}
