import 'package:caresitter_customer/features/auth/presentation/widgets/recovery_email_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailCodeStep extends ConsumerWidget {
  const RecoveryEmailCodeStep(
      {super.key,
      required this.email,
      required this.code,
      required this.flow,
      required this.request});
  final TextEditingController email;
  final TextEditingController code;
  final RecoveryEmailState flow;
  final Future<void> Function({bool resend}) request;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mã đã được yêu cầu gửi tới ${email.text.trim()}.'),
            const SizedBox(height: AppSpacing.md),
            RecoveryEmailCodeField(
                code: code, busy: flow.busy, expired: flow.expired),
            if (flow.expired) const Text('Mã đã hết hạn. Hãy gửi lại mã.'),
            TextButton(
                onPressed: flow.busy || flow.remaining > 0
                    ? null
                    : () => request(resend: true),
                child: Text(flow.remaining > 0
                    ? 'Gửi lại sau ${flow.remaining}s'
                    : 'Gửi lại mã')),
            TextButton(
                onPressed: flow.busy
                    ? null
                    : () {
                        ref
                            .read(recoveryEmailControllerProvider.notifier)
                            .changeInfo();
                        code.clear();
                      },
                child: const Text('Đổi thông tin')),
          ]);
}
