import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginRecoveryLink extends StatelessWidget {
  const LoginRecoveryLink({super.key, required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed:
              isLoading ? null : () => context.push('/auth/forgot-password'),
          child: const Text('Quên mật khẩu?'),
        ),
      );
}
