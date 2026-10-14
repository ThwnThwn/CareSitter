import 'package:caresitter_customer/features/auth/presentation/widgets/recovery_email_field.dart';
import 'package:flutter/material.dart';
import '../../domain/recovery_input_rules.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailInputFields extends StatelessWidget {
  const RecoveryEmailInputFields(
      {super.key,
      required this.email,
      required this.flow,
      required this.onEmailChanged,
      required this.changing,
      required this.password,
      required this.hidden,
      required this.onTogglePassword});
  final TextEditingController email;
  final RecoveryEmailState flow;
  final void Function(String) onEmailChanged;
  final bool changing;
  final TextEditingController password;
  final bool hidden;
  final void Function() onTogglePassword;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecoveryEmailField(
                email: email,
                busy: flow.busy,
                hasPassword: flow.hasPassword,
                onEmailChanged: onEmailChanged),
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
                          onPressed: onTogglePassword,
                          icon: Icon(hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined))),
                  validator: RecoveryInputRules.currentPassword),
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
