import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class PasswordRecoverySuccessStep extends StatelessWidget {
  const PasswordRecoverySuccessStep({super.key, required this.onSignIn});
  final void Function() onSignIn;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 56, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            const Text(
                'Mật khẩu đã được thay đổi và mọi phiên đăng nhập cũ đã bị thu hồi. Hãy đăng nhập bằng mật khẩu mới.'),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
                onPressed: onSignIn, child: const Text('Về đăng nhập')),
          ]);
}
