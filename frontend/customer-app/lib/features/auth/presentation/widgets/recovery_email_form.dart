import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/recovery_email_controller.dart';
import 'recovery_email_identity_summary.dart';
import 'recovery_email_input_fields.dart';
import 'recovery_email_code_step.dart';
import 'recovery_email_feedback.dart';
import 'recovery_email_submit_button.dart';

class RecoveryEmailForm extends StatelessWidget {
  const RecoveryEmailForm(
      {super.key,
      required this.form,
      required this.flow,
      required this.email,
      required this.changing,
      required this.password,
      required this.hidden,
      required this.code,
      required this.onRequest,
      required this.onConfirm,
      required this.onEmailChanged,
      required this.onTogglePassword});
  final GlobalKey<FormState> form;
  final RecoveryEmailState flow;
  final TextEditingController email, password, code;
  final bool changing, hidden;
  final Future<void> Function({bool resend}) onRequest;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onConfirm;
  final ValueChanged<String> onEmailChanged;

  @override
  Widget build(BuildContext context) => Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecoveryEmailIdentitySummary(
              email: flow.currentEmail!, verified: flow.verified),
          if (flow.challengeId == null)
            RecoveryEmailInputFields(
                email: email,
                flow: flow,
                changing: changing,
                password: password,
                hidden: hidden,
                onEmailChanged: onEmailChanged,
                onTogglePassword: onTogglePassword)
          else
            RecoveryEmailCodeStep(
                email: email, code: code, flow: flow, request: onRequest),
          if (flow.error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
                liveRegion: true,
                child: Text(flow.error!,
                    style: const TextStyle(color: AppColors.error))),
          ],
          if (flow.message != null) RecoveryEmailFeedback(flow: flow),
          const SizedBox(height: AppSpacing.lg),
          RecoveryEmailSubmitButton(
              busy: flow.busy,
              challenge: flow.challengeId,
              expired: flow.expired,
              request: onRequest,
              confirm: onConfirm),
        ],
      ));
}
