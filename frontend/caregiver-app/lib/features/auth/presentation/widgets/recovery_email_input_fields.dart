import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email/steps/recovery_email_input_step.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailInputFields extends StatelessWidget {
  const RecoveryEmailInputFields(
      {super.key,
      required this.email,
      required this.flow,
      required this.changing,
      required this.password,
      required this.hidden,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction7,
      required this.callbackAction8});
  final TextEditingController email;
  final RecoveryEmailState flow;
  final bool changing;
  final TextEditingController password;
  final bool hidden;
  final void Function(String) callbackAction1;
  final String? Function(String?) callbackAction2;
  final void Function() callbackAction7;
  final String? Function(String?) callbackAction8;

  @override
  Widget build(BuildContext context) => RecoveryEmailInputStep(
      email: email,
      flow: flow,
      changing: changing,
      password: password,
      hidden: hidden,
      callbackAction3: callbackAction1,
      callbackAction4: callbackAction2,
      callbackAction5: callbackAction7,
      callbackAction6: callbackAction8);
}
