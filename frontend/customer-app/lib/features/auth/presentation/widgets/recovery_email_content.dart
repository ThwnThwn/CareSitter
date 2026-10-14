import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/recovery_email_controller.dart';
import 'recovery_email_app_bar.dart';
import 'recovery_email_form.dart';

class RecoveryEmailContent extends StatelessWidget {
  const RecoveryEmailContent(
      {super.key,
      required this.flow,
      required this.onReload,
      required this.form,
      required this.email,
      required this.changing,
      required this.password,
      required this.hidden,
      required this.code,
      required this.onRequest,
      required this.onConfirm,
      required this.onEmailChanged,
      required this.onTogglePassword});
  final RecoveryEmailState flow;
  final GlobalKey<FormState> form;
  final TextEditingController email, password, code;
  final bool changing, hidden;
  final VoidCallback onReload, onTogglePassword;
  final Future<void> Function() onConfirm;
  final Future<void> Function({bool resend}) onRequest;
  final ValueChanged<String> onEmailChanged;

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
                                onPressed: onReload,
                                child: const Text('Tải lại')),
                          ])
                        : RecoveryEmailForm(
                            form: form,
                            flow: flow,
                            email: email,
                            changing: changing,
                            password: password,
                            hidden: hidden,
                            code: code,
                            onRequest: onRequest,
                            onConfirm: onConfirm,
                            onEmailChanged: onEmailChanged,
                            onTogglePassword: onTogglePassword),
              )),
        )),
      );
}
