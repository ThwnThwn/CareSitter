import 'package:caresitter_customer/features/auth/presentation/widgets/password_recovery_email_field.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryEmailStep extends StatelessWidget {
  const PasswordRecoveryEmailStep(
      {super.key,
      required this.email,
      required this.flow,
      required this.callbackAction1,
      required this.callbackAction2});
  final TextEditingController email;
  final PasswordRecoveryState flow;
  final void Function(String) callbackAction1;
  final String? Function(String?) callbackAction2;

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
                action1: callbackAction1,
                action2: callbackAction2),
            const SizedBox(height: AppSpacing.md),
            const Text(
                'Chưa xác minh email? Đăng nhập bằng mã email trước để xác minh. Nếu mất quyền truy cập email, cần liên hệ đơn vị hỗ trợ.',
                style: TextStyle(color: AppColors.textSecondary)),
            TextButton(
                onPressed: flow.busy ? null : () => context.go('/auth/email'),
                child: const Text('Đăng nhập bằng mã email')),
          ]);
}
