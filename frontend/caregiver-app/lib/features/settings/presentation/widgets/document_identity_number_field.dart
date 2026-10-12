import 'package:flutter/material.dart';

class DocumentIdentityNumberField extends StatelessWidget {
  const DocumentIdentityNumberField(
      {super.key, required this.cccdController, required this.callbackAction1});
  final TextEditingController cccdController;
  final String? Function(String?) callbackAction1;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: cccdController,
        keyboardType: TextInputType.number,
        maxLength: 12,
        decoration: const InputDecoration(
          labelText: 'Số CCCD',
          hintText: 'Nhập 9 hoặc 12 chữ số',
        ),
        validator: callbackAction1,
      );
}
