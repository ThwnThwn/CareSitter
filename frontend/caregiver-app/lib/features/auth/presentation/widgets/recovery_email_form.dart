import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_identity_summary.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_input_fields.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email/steps/recovery_email_code_step.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_submit_button.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailForm extends StatelessWidget {
  const RecoveryEmailForm(
      {super.key,
      required this.form,
      required this.flow,
      required this.email,
      required this.changing,
      required this.password,
      required this.hidden,
      required this.callbackAction4,
      required this.callbackAction5,
      required this.callbackAction6,
      required this.callbackAction9,
      required this.code,
      required this.request,
      required this.ref,
      required this.callbackAction10,
      required this.confirm});
  final GlobalKey<FormState> form;
  final RecoveryEmailState flow;
  final TextEditingController email;
  final bool changing;
  final TextEditingController password;
  final bool hidden;
  final void Function(String) callbackAction4;
  final String? Function(String?) callbackAction5;
  final void Function() callbackAction6;
  final String? Function(String?) callbackAction9;
  final TextEditingController code;
  final Future<void> Function({bool resend}) request;
  final WidgetRef ref;
  final String? Function(String?) callbackAction10;
  final Future<void> Function() confirm;

  @override
  Widget build(BuildContext context) => Form(
      key: form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RecoveryEmailIdentitySummary(
            email: flow.currentEmail!, verified: flow.verified),
        if (flow.challengeId == null)
          RecoveryEmailInputFields(
              email: email,
              flow: flow,
              changing: changing,
              password: password,
              hidden: hidden,
              callbackAction1: callbackAction4,
              callbackAction2: callbackAction5,
              callbackAction7: callbackAction6,
              callbackAction8: callbackAction9)
        else
          RecoveryEmailCodeStep(
              email: email,
              code: code,
              flow: flow,
              request: request,
              ref: ref,
              callbackAction3: callbackAction10),
        if (flow.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
              liveRegion: true,
              child: Text(flow.error!,
                  style: const TextStyle(color: AppColors.error))),
        ],
        if (flow.message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
              liveRegion: true,
              child: Text(flow.message!,
                  style: const TextStyle(color: AppColors.primary))),
        ],
        const SizedBox(height: AppSpacing.lg),
        RecoveryEmailSubmitButton(
            flow: flow, request: request, confirm: confirm),
      ]));
}
