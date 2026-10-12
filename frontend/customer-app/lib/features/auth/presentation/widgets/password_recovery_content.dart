import 'package:caresitter_customer/features/auth/presentation/widgets/password_recovery_form.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/password_recovery_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryContent extends StatelessWidget {
  const PasswordRecoveryContent(
      {super.key,
      required this.flow,
      required this.form,
      required this.title,
      required this.email,
      required this.code,
      required this.request,
      required this.password,
      required this.hidden,
      required this.validatePassword,
      required this.confirmation,
      required this.submit,
      required this.startOver,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.callbackAction5,
      required this.callbackAction6,
      required this.callbackAction7,
      required this.callbackAction8});
  final PasswordRecoveryState flow;
  final GlobalKey<FormState> form;
  final String title;
  final TextEditingController email;
  final TextEditingController code;
  final Future<void> Function({bool resend}) request;
  final TextEditingController password;
  final bool hidden;
  final String? Function(String?) validatePassword;
  final TextEditingController confirmation;
  final Future<void> Function() submit;
  final void Function() startOver;
  final void Function(String) callbackAction1;
  final String? Function(String?) callbackAction2;
  final void Function(String) callbackAction3;
  final String? Function(String?) callbackAction4;
  final void Function() callbackAction5;
  final String? Function(String?) callbackAction6;
  final void Function(String) callbackAction7;
  final void Function() callbackAction8;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: PasswordRecoveryAppBar(flow: flow),
        body: PasswordRecoveryForm(
            form: form,
            flow: flow,
            title: title,
            email: email,
            callbackAction1: callbackAction1,
            callbackAction2: callbackAction2,
            code: code,
            callbackAction3: callbackAction3,
            callbackAction4: callbackAction4,
            request: request,
            password: password,
            hidden: hidden,
            validatePassword: validatePassword,
            callbackAction5: callbackAction5,
            confirmation: confirmation,
            callbackAction6: callbackAction6,
            callbackAction7: callbackAction7,
            callbackAction8: callbackAction8,
            submit: submit,
            startOver: startOver),
      );
}
