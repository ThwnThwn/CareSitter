import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class RecoveryEmailIdentitySummary extends StatelessWidget {
  const RecoveryEmailIdentitySummary(
      {super.key, required this.email, required this.verified});
  final String email;
  final bool verified;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Bảo vệ quyền đăng nhập',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.compact),
          const Text(
              'Xác minh email để có thể nhận mã khi quên mật khẩu. Email đăng nhập cũng là email khôi phục.'),
          const SizedBox(height: AppSpacing.section),
          Text(email, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Text(verified ? 'Đã xác minh' : 'Chưa xác minh',
              style: TextStyle(
                  color:
                      verified ? AppColors.primary : AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.lg),
        ],
      );
}
