import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class LoginRegisterLink extends StatelessWidget {
  const LoginRegisterLink({super.key, required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Bạn chưa có tài khoản?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          TextButton(
            onPressed: isLoading ? null : () => context.push('/auth/register'),
            child: const Text('Đăng ký Caregiver'),
          ),
        ],
      );
}
