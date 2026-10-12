import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoverySubmitButton extends StatelessWidget {
  const PasswordRecoverySubmitButton(
      {super.key, required this.flow, required this.submit});
  final PasswordRecoveryState flow;
  final Future<void> Function() submit;
  @override
  Widget build(BuildContext context) => FilledButton(
      onPressed: flow.busy || (flow.step == 1 && flow.expired) ? null : submit,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.inset),
          child: flow.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text([
                  'Gửi mã khôi phục',
                  'Xác minh mã',
                  'Đặt mật khẩu mới'
                ][flow.step])));
}
