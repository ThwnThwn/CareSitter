import 'package:caresitter_customer/features/auth/presentation/widgets/recovery_email_field.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailInputFields extends StatelessWidget {
  const RecoveryEmailInputFields(
      {super.key,
      required this.email,
      required this.flow,
      required this.callbackAction1,
      required this.changing,
      required this.password,
      required this.hidden,
      required this.callbackAction2,
      required this.callbackAction3});
  final TextEditingController email;
  final RecoveryEmailState flow;
  final void Function(String) callbackAction1;
  final bool changing;
  final TextEditingController password;
  final bool hidden;
  final void Function() callbackAction2;
  final String? Function(String?) callbackAction3;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecoveryEmailField(
                email: email,
                busy: flow.busy,
                hasPassword: flow.hasPassword,
                action1: callbackAction1),
            if (changing) ...[
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                  controller: password,
                  enabled: !flow.busy,
                  obscureText: hidden,
                  decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      suffixIcon: IconButton(
                          tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          onPressed: callbackAction2,
                          icon: Icon(hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined))),
                  validator: callbackAction3),
              const SizedBox(height: AppSpacing.compact),
              const Text(
                  'Email chỉ thay đổi sau khi nhập đúng mã gửi tới email mới. Sau đó mọi phiên sẽ bị thu hồi và bạn cần đăng nhập lại.'),
            ],
            if (!flow.hasPassword) ...[
              const SizedBox(height: AppSpacing.compact),
              const Text(
                  'Tài khoản chỉ dùng Google/OTP có thể xác minh email hiện tại. Việc đổi email cần liên hệ đơn vị hỗ trợ.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ]);
}
