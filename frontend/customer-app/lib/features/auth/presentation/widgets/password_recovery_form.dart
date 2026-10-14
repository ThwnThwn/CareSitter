import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/password_recovery_controller.dart';
import 'password_recovery_email_step.dart';
import 'password_recovery_code_step.dart';
import 'password_recovery_new_password_step.dart';
import 'password_recovery_success_step.dart';
import 'password_recovery_actions.dart';

class PasswordRecoveryForm extends StatelessWidget {
  const PasswordRecoveryForm(
      {super.key,
      required this.form,
      required this.flow,
      required this.email,
      required this.code,
      required this.password,
      required this.confirmation,
      required this.hidden,
      required this.onRequest,
      required this.onSubmit,
      required this.onStartOver,
      required this.onTogglePassword,
      required this.onSignIn});
  final GlobalKey<FormState> form;
  final PasswordRecoveryState flow;
  final TextEditingController email, code, password, confirmation;
  final bool hidden;
  final Future<void> Function({bool resend}) onRequest;
  final Future<void> Function() onSubmit;
  final VoidCallback onStartOver, onTogglePassword, onSignIn;

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
                          Text(
                              [
                                'Quên mật khẩu',
                                'Xác minh email',
                                'Đặt mật khẩu mới',
                                'Đã đổi mật khẩu'
                              ][flow.step],
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: AppSpacing.compact),
                          if (flow.step == 0)
                            PasswordRecoveryEmailStep(
                                email: email, flow: flow, onSubmit: onSubmit),
                          if (flow.step == 1)
                            PasswordRecoveryCodeStep(
                                flow: flow,
                                email: email,
                                code: code,
                                onSubmit: onSubmit,
                                request: onRequest),
                          if (flow.step == 2)
                            PasswordRecoveryNewPasswordStep(
                                password: password,
                                flow: flow,
                                hidden: hidden,
                                confirmation: confirmation,
                                onTogglePassword: onTogglePassword,
                                onSubmit: onSubmit),
                          if (flow.step == 3)
                            PasswordRecoverySuccessStep(onSignIn: onSignIn),
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
                                submit: onSubmit,
                                startOver: onStartOver),
                        ],
                      ))),
            )),
      ));
}
