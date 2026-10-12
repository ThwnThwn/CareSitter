import 'package:flutter/material.dart';

class RegistrationConfirmationField extends StatelessWidget {
  const RegistrationConfirmationField(
      {super.key,
      required this.passwordField,
      required this.confirmController,
      required this.hideConfirmation,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3});
  final Widget Function(
      {required TextEditingController controller,
      required bool hidden,
      required String label,
      void Function(String)? onSubmitted,
      required void Function() onToggle,
      required String? Function(String?) validator}) passwordField;
  final TextEditingController confirmController;
  final bool hideConfirmation;
  final String? Function(String?) callbackAction1;
  final void Function() callbackAction2;
  final void Function(String) callbackAction3;

  @override
  Widget build(BuildContext context) => passwordField(
        controller: confirmController,
        label: 'Xác nhận mật khẩu',
        hidden: hideConfirmation,
        validator: callbackAction1,
        onToggle: callbackAction2,
        onSubmitted: callbackAction3,
      );
}
