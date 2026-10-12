import 'package:caresitter_customer/features/auth/presentation/widgets/recovery_email_body.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/recovery_email_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailContent extends StatelessWidget {
  const RecoveryEmailContent(
      {super.key,
      required this.flow,
      required this.load,
      required this.form,
      required this.email,
      required this.changing,
      required this.password,
      required this.hidden,
      required this.code,
      required this.request,
      required this.ref,
      required this.confirm,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3});
  final RecoveryEmailState flow;
  final Future<void> Function() load;
  final GlobalKey<FormState> form;
  final TextEditingController email;
  final bool changing;
  final TextEditingController password;
  final bool hidden;
  final TextEditingController code;
  final Future<void> Function({bool resend}) request;
  final WidgetRef ref;
  final Future<void> Function() confirm;
  final void Function(String) callbackAction1;
  final void Function() callbackAction2;
  final String? Function(String?) callbackAction3;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: RecoveryEmailAppBar(flow: flow),
        body: RecoveryEmailBody(
            flow: flow,
            load: load,
            form: form,
            email: email,
            callbackAction1: callbackAction1,
            changing: changing,
            password: password,
            hidden: hidden,
            callbackAction2: callbackAction2,
            callbackAction3: callbackAction3,
            code: code,
            request: request,
            ref: ref,
            confirm: confirm),
      );
}
