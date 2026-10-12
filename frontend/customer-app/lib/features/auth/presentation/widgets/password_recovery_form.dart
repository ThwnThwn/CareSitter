import 'package:caresitter_customer/features/auth/presentation/widgets/password_recovery_new_password_step.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/password_recovery_code_step.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/password_recovery_email_step.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/password_recovery_actions.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/password_recovery_success_step.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryForm extends StatelessWidget {
  const PasswordRecoveryForm(
      {super.key,
      required this.form,
      required this.flow,
      required this.title,
      required this.email,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.code,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.request,
      required this.password,
      required this.hidden,
      required this.validatePassword,
      required this.callbackAction5,
      required this.confirmation,
      required this.callbackAction6,
      required this.callbackAction7,
      required this.callbackAction8,
      required this.submit,
      required this.startOver});
  final GlobalKey<FormState> form;
  final PasswordRecoveryState flow;
  final String title;
  final TextEditingController email;
  final void Function(String) callbackAction1;
  final String? Function(String?) callbackAction2;
  final TextEditingController code;
  final void Function(String) callbackAction3;
  final String? Function(String?) callbackAction4;
  final Future<void> Function({bool resend}) request;
  final TextEditingController password;
  final bool hidden;
  final String? Function(String?) validatePassword;
  final void Function() callbackAction5;
  final TextEditingController confirmation;
  final String? Function(String?) callbackAction6;
  final void Function(String) callbackAction7;
  final void Function() callbackAction8;
  final Future<void> Function() submit;
  final void Function() startOver;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AutofillGroup(
                    child: Form(
                        key: form,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (flow.step < 3) ...[
                                Text('Bước ${flow.step + 1} / 3',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: AppSpacing.compact),
                              ],
                              Text(title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: AppSpacing.compact),
                              if (flow.step == 0)
                                PasswordRecoveryEmailStep(
                                    email: email,
                                    flow: flow,
                                    callbackAction1: callbackAction1,
                                    callbackAction2: callbackAction2),
                              if (flow.step == 1)
                                PasswordRecoveryCodeStep(
                                    flow: flow,
                                    email: email,
                                    code: code,
                                    callbackAction3: callbackAction3,
                                    callbackAction4: callbackAction4,
                                    request: request),
                              if (flow.step == 2)
                                PasswordRecoveryNewPasswordStep(
                                    password: password,
                                    flow: flow,
                                    hidden: hidden,
                                    validatePassword: validatePassword,
                                    callbackAction5: callbackAction5,
                                    confirmation: confirmation,
                                    callbackAction6: callbackAction6,
                                    callbackAction7: callbackAction7),
                              if (flow.step == 3)
                                PasswordRecoverySuccessStep(
                                    callbackAction8: callbackAction8),
                              if (flow.error != null) ...[
                                const SizedBox(height: AppSpacing.md),
                                Semantics(
                                    liveRegion: true,
                                    child: Text(flow.error!,
                                        style: const TextStyle(
                                            color: AppColors.error))),
                              ],
                              if (flow.step < 3)
                                PasswordRecoveryActions(
                                    flow: flow,
                                    submit: submit,
                                    startOver: startOver),
                            ]))),
              )),
        ),
      );
}
