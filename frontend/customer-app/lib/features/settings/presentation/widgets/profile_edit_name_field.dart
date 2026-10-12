import 'package:flutter/material.dart';

class ProfileEditNameField extends StatelessWidget {
  const ProfileEditNameField(
      {super.key,
      required this.nameCtrl,
      required this.callbackAction1,
      required this.callbackAction2});
  final TextEditingController nameCtrl;
  final void Function(String) callbackAction1;
  final String? Function(String?) callbackAction2;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: nameCtrl,
        decoration: const InputDecoration(
          labelText: 'Họ và tên *',
          prefixIcon: Icon(Icons.person_outline),
        ),
        onChanged: callbackAction1, // cập nhật initials realtime
        validator: callbackAction2,
      );
}
