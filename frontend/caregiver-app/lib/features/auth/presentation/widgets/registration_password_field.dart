import 'package:flutter/material.dart';

class RegistrationPasswordField extends StatelessWidget {
  const RegistrationPasswordField(
      {super.key,
      required this.controller,
      required this.hidden,
      required this.onSubmitted,
      required this.validator,
      required this.label,
      required this.onToggle});
  final TextEditingController controller;
  final bool hidden;
  final void Function(String)? onSubmitted;
  final String? Function(String?) validator;
  final String label;
  final void Function() onToggle;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: hidden,
      textInputAction:
          onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      validator: validator,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed: onToggle,
          icon: Icon(hidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined),
        ),
      ),
    );
  }
}
