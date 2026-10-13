import 'package:flutter/material.dart';

class RegistrationPasswordField extends StatefulWidget {
  const RegistrationPasswordField(
      {super.key,
      required this.controller,
      this.enabled = true,
      this.onSubmitted,
      required this.validator,
      required this.label});
  final TextEditingController controller;
  final bool enabled;
  final void Function(String)? onSubmitted;
  final String? Function(String?) validator;
  final String label;
  @override
  State<RegistrationPasswordField> createState() =>
      _RegistrationPasswordFieldState();
}

class _RegistrationPasswordFieldState extends State<RegistrationPasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _hidden,
      textInputAction:
          widget.onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          onPressed:
              widget.enabled ? () => setState(() => _hidden = !_hidden) : null,
          icon: Icon(
              _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        ),
      ),
    );
  }
}
