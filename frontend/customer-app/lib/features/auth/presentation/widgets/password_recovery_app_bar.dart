import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const PasswordRecoveryAppBar({super.key, required this.flow});
  final PasswordRecoveryState flow;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
      title: const Text('Khôi phục mật khẩu'),
      leading: IconButton(
          tooltip: 'Về đăng nhập',
          icon: const Icon(Icons.arrow_back),
          onPressed: flow.busy
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.login);
                  }
                }));
}
