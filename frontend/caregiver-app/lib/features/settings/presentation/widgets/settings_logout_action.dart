import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';

class SettingsLogoutAction extends StatelessWidget {
  const SettingsLogoutAction({super.key, required this.onLogout});
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: AppButton(
          label: 'Đăng xuất',
          icon: Icons.logout_rounded,
          backgroundColor: AppColors.errorLight,
          foregroundColor: AppColors.error,
          onPressed: onLogout,
        ),
      );
}
