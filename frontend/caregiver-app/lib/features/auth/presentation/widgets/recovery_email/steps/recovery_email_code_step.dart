import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_code_field.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_change_action.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailCodeStep extends StatelessWidget {
  const RecoveryEmailCodeStep(
      {super.key,
      required this.email,
      required this.code,
      required this.flow,
      required this.request,
      required this.ref,
      required this.callbackAction3});
  final TextEditingController email;
  final TextEditingController code;
  final RecoveryEmailState flow;
  final Future<void> Function({bool resend}) request;
  final WidgetRef ref;
  final String? Function(String?) callbackAction3;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mã đã được yêu cầu gửi tới ${email.text.trim()}.'),
            const SizedBox(height: AppSpacing.md),
            RecoveryEmailCodeField(
                code: code, flow: flow, callbackAction1: callbackAction3),
            if (flow.expired) const Text('Mã đã hết hạn. Hãy gửi lại mã.'),
            TextButton(
                onPressed: flow.busy || flow.remaining > 0
                    ? null
                    : () => request(resend: true),
                child: Text(flow.remaining > 0
                    ? 'Gửi lại sau ${flow.remaining}s'
                    : 'Gửi lại mã')),
            RecoveryEmailChangeAction(flow: flow, ref: ref, code: code),
          ]);
}
