import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_form.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_app_bar.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

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
      required this.callbackAction4,
      required this.callbackAction5,
      required this.callbackAction6,
      required this.callbackAction9,
      required this.callbackAction10});
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
  final void Function(String) callbackAction4;
  final String? Function(String?) callbackAction5;
  final void Function() callbackAction6;
  final String? Function(String?) callbackAction9;
  final String? Function(String?) callbackAction10;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: RecoveryEmailAppBar(flow: flow),
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: flow.loading
                          ? const LinearProgressIndicator()
                          : flow.currentEmail == null
                              ? Column(children: [
                                  Text(flow.error ?? 'Chưa tải được email.'),
                                  TextButton(
                                      onPressed: load,
                                      child: const Text('Tải lại')),
                                ])
                              : RecoveryEmailForm(
                                  form: form,
                                  flow: flow,
                                  email: email,
                                  changing: changing,
                                  password: password,
                                  hidden: hidden,
                                  callbackAction4: callbackAction4,
                                  callbackAction5: callbackAction5,
                                  callbackAction6: callbackAction6,
                                  callbackAction9: callbackAction9,
                                  code: code,
                                  request: request,
                                  ref: ref,
                                  callbackAction10: callbackAction10,
                                  confirm: confirm),
                    )))),
      );
}
