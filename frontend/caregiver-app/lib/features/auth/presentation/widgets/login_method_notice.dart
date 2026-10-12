import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class LoginMethodNotice extends StatelessWidget {
  const LoginMethodNotice({super.key, required this.usePassword});
  final bool usePassword;

  @override
  Widget build(BuildContext context) => Text(
        usePassword
            ? 'Nhập email hoặc số điện thoại và mật khẩu'
            : 'Nhập email để nhận mã OTP',
        style: const TextStyle(
          fontSize: AppFontSizes.s14,
          color: AppColors.textSecondary,
        ),
      );
}
