import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery/steps/password_recovery_code_step.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery/steps/password_recovery_email_step.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery/steps/password_recovery_password_step.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery_actions.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery/steps/password_recovery_success_step.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery_app_bar.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

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
      required this.callbackAction6,
      required this.callbackAction7,
      required this.callbackAction8,
      required this.callbackAction9,
      required this.callbackAction10,
      required this.callbackAction11});
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
  final void Function(String) callbackAction6;
  final String? Function(String?) callbackAction7;
  final void Function() callbackAction8;
  final String? Function(String?) callbackAction9;
  final void Function(String) callbackAction10;
  final void Function() callbackAction11;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: PasswordRecoveryAppBar(flow: flow),
        body: SafeArea(
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
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: AppSpacing.compact),
                                if (flow.step == 0)
                                  PasswordRecoveryEmailStep(
                                      email: email,
                                      flow: flow,
                                      callbackAction3: callbackAction1,
                                      callbackAction4: callbackAction2),
                                if (flow.step == 1)
                                  PasswordRecoveryCodeStep(
                                      flow: flow,
                                      email: email,
                                      code: code,
                                      request: request,
                                      callbackAction3: callbackAction6,
                                      callbackAction4: callbackAction7),
                                if (flow.step == 2)
                                  PasswordRecoveryPasswordStep(
                                      password: password,
                                      flow: flow,
                                      hidden: hidden,
                                      validatePassword: validatePassword,
                                      confirmation: confirmation,
                                      callbackAction3: callbackAction8,
                                      callbackAction4: callbackAction9,
                                      callbackAction5: callbackAction10),
                                if (flow.step == 3)
                                  PasswordRecoverySuccessStep(
                                      callbackAction3: callbackAction11),
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
        ),
      );
}
