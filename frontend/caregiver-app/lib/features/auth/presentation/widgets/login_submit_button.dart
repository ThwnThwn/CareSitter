import 'package:flutter/material.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';

class LoginSubmitButton extends StatelessWidget {
  const LoginSubmitButton(
      {super.key,
      required this.usePassword,
      required this.loginWithPassword,
      required this.requestOtp,
      required this.isLoading});
  final bool usePassword;
  final Future<void> Function() loginWithPassword;
  final Future<void> Function() requestOtp;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => AppButton(
        label: usePassword ? 'Đăng nhập' : 'Gửi mã OTP',
        onPressed: usePassword ? loginWithPassword : requestOtp,
        isLoading: isLoading,
        icon: usePassword ? Icons.login_rounded : Icons.send_rounded,
      );
}
