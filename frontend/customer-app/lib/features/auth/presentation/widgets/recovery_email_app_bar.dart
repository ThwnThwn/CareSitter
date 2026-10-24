import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const RecoveryEmailAppBar({super.key, required this.flow});
  final RecoveryEmailState flow;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
      title: const Text('Email khôi phục'),
      leading: IconButton(
          tooltip: 'Về cài đặt',
          icon: const Icon(Icons.arrow_back),
          onPressed: flow.busy
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.settings);
                  }
                }));
}
