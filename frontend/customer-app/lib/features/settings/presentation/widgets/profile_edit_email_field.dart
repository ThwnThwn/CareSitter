import 'package:flutter/material.dart';

class ProfileEditEmailField extends StatelessWidget {
  const ProfileEditEmailField(
      {super.key,
      required this.emailCtrl,
      required this.callbackAction3,
      required this.callbackAction4});
  final TextEditingController emailCtrl;
  final void Function() callbackAction3;
  final String? Function(String?) callbackAction4;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: emailCtrl,
        readOnly: true,
        onTap: callbackAction3,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          helperText: 'Chạm để xác minh hoặc đổi email an toàn.',
          prefixIcon: Icon(Icons.email_outlined),
        ),
        validator: callbackAction4,
      );
}
