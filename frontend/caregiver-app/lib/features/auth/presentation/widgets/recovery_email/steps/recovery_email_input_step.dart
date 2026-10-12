import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_password_field.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/recovery_email_field.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailInputStep extends StatelessWidget {
  const RecoveryEmailInputStep(
      {super.key,
      required this.email,
      required this.flow,
      required this.changing,
      required this.password,
      required this.hidden,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.callbackAction5,
      required this.callbackAction6});
  final TextEditingController email;
  final RecoveryEmailState flow;
  final bool changing;
  final TextEditingController password;
  final bool hidden;
  final void Function(String) callbackAction3;
  final String? Function(String?) callbackAction4;
  final void Function() callbackAction5;
  final String? Function(String?) callbackAction6;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RecoveryEmailField(
                email: email,
                flow: flow,
                callbackAction1: callbackAction3,
                callbackAction2: callbackAction4),
            if (changing) ...[
              const SizedBox(height: AppSpacing.md),
              RecoveryEmailPasswordField(
                  password: password,
                  flow: flow,
                  hidden: hidden,
                  callbackAction1: callbackAction5,
                  callbackAction2: callbackAction6),
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
