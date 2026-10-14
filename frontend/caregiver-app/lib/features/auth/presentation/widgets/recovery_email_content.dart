import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_form.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_app_bar.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
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
      required this.confirm,
      required this.onEmailChanged,
      required this.onTogglePassword});
  final RecoveryEmailState flow;
  final Future<void> Function() load;
  final GlobalKey<FormState> form;
  final TextEditingController email;
  final bool changing;
  final TextEditingController password;
  final bool hidden;
  final TextEditingController code;
  final Future<void> Function({bool resend}) request;
  final Future<void> Function() confirm;
  final void Function(String) onEmailChanged;
  final void Function() onTogglePassword;

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
                                  onEmailChanged: onEmailChanged,
                                  onTogglePassword: onTogglePassword,
                                  code: code,
                                  request: request,
                                  confirm: confirm),
                    )))),
      );
}
