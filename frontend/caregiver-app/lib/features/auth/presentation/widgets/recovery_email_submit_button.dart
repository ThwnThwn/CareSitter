import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailSubmitButton extends StatelessWidget {
  const RecoveryEmailSubmitButton(
      {super.key,
      required this.flow,
      required this.request,
      required this.confirm});
  final RecoveryEmailState flow;
  final Future<void> Function({bool resend}) request;
  final Future<void> Function() confirm;

  @override
  Widget build(BuildContext context) => FilledButton(
      onPressed: flow.busy || (flow.challengeId != null && flow.expired)
          ? null
          : flow.challengeId == null
              ? request
              : confirm,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.inset),
          child: flow.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(flow.challengeId == null
                  ? 'Gửi mã xác minh'
                  : 'Xác minh email')));
}
