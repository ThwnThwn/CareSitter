import 'package:caregiver_app/features/auth/presentation/widgets/registration_confirmation_field.dart';
import 'package:flutter/material.dart';

class RegistrationPasswordFields extends StatelessWidget {
  const RegistrationPasswordFields(
      {super.key,
      required this.passwordField,
      required this.confirmController,
      required this.hideConfirmation,
      required this.callbackAction4,
      required this.callbackAction5,
      required this.callbackAction6});
  final Widget Function(
      {required TextEditingController controller,
      required bool hidden,
      required String label,
      void Function(String)? onSubmitted,
      required void Function() onToggle,
      required String? Function(String?) validator}) passwordField;
  final TextEditingController confirmController;
  final bool hideConfirmation;
  final String? Function(String?) callbackAction4;
  final void Function() callbackAction5;
  final void Function(String) callbackAction6;

  @override
  Widget build(BuildContext context) => RegistrationConfirmationField(
      passwordField: passwordField,
      confirmController: confirmController,
      hideConfirmation: hideConfirmation,
      callbackAction1: callbackAction4,
      callbackAction2: callbackAction5,
      callbackAction3: callbackAction6);
}
