import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery_code_field.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryCodeStep extends StatelessWidget {
  const PasswordRecoveryCodeStep({
    super.key,
    required this.flow,
    required this.email,
    required this.code,
    required this.request,
    required this.onSubmit,
  });
  final PasswordRecoveryState flow;
  final TextEditingController email;
  final TextEditingController code;
  final Future<void> Function({bool resend}) request;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(flow.message),
            const SizedBox(height: AppSpacing.sm),
            Text(email.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.lg),
            PasswordRecoveryCodeField(
              code: code,
              flow: flow,
              onSubmit: onSubmit,
            ),
            Text(
                flow.expired
                    ? 'Mã đã hết hạn. Hãy gửi lại mã.'
                    : 'Mã có hiệu lực ${(flow.expiresIn / 60).ceil()} phút.',
                style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(
                onPressed: flow.busy || flow.remaining > 0
                    ? null
                    : () => request(resend: true),
                child: Text(flow.remaining > 0
                    ? 'Gửi lại sau ${flow.remaining}s'
                    : 'Gửi lại mã')),
          ]);
}
