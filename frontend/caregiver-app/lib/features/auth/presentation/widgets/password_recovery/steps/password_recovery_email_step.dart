import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery_email_field.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryEmailStep extends StatelessWidget {
  const PasswordRecoveryEmailStep(
      {super.key,
      required this.email,
      required this.flow,
      required this.callbackAction3,
      required this.callbackAction4});
  final TextEditingController email;
  final PasswordRecoveryState flow;
  final void Function(String) callbackAction3;
  final String? Function(String?) callbackAction4;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Nhập email đã xác minh với CareSitter để nhận mã khôi phục.'),
            const SizedBox(height: AppSpacing.lg),
            PasswordRecoveryEmailField(
                email: email,
                flow: flow,
                callbackAction1: callbackAction3,
                callbackAction2: callbackAction4),
            const SizedBox(height: AppSpacing.md),
            const Text(
                'Chưa xác minh email? Đăng nhập bằng mã email trước để xác minh. Nếu mất quyền truy cập email, cần liên hệ đơn vị hỗ trợ.',
                style: TextStyle(color: AppColors.textSecondary)),
            TextButton(
                onPressed: flow.busy
                    ? null
                    : () => context.go('/auth/phone?method=otp'),
                child: const Text('Đăng nhập bằng mã email')),
          ]);
}
