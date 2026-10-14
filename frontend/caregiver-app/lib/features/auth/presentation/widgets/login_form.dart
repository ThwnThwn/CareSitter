import 'package:caregiver_app/features/auth/presentation/widgets/login_method_toggle.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/login_password_field.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/login_identifier_field.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/login_register_link.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/login_submit_button.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/login_recovery_link.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/login_method_notice.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class LoginForm extends StatelessWidget {
  const LoginForm(
      {super.key,
      required this.usePassword,
      required this.identifierController,
      required this.passwordController,
      required this.obscurePassword,
      required this.isLoading,
      required this.loginWithPassword,
      required this.requestOtp,
      required this.onMethodChanged,
      required this.onTogglePassword});
  final bool usePassword;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final Future<void> Function() loginWithPassword;
  final Future<void> Function() requestOtp;
  final ValueChanged<bool> onMethodChanged;
  final void Function() onTogglePassword;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Đăng nhập tài khoản',
            style: TextStyle(
              fontSize: AppFontSizes.s22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.tight),
          LoginMethodNotice(usePassword: usePassword),
          const SizedBox(height: AppSpacing.md),

          // Toggle Mật khẩu / OTP
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.compact),
            ),
            child: LoginMethodToggle(
                usePassword: usePassword, onChanged: onMethodChanged),
          ),
          const SizedBox(height: AppSpacing.section),

          // Email / Phone field
          LoginIdentifierField(
              identifierController: identifierController,
              usePassword: usePassword),
          const SizedBox(height: AppSpacing.md),

          // Password field (nếu usePassword)
          if (usePassword) ...[
            LoginPasswordField(
                passwordController: passwordController,
                obscurePassword: obscurePassword,
                onTogglePassword: onTogglePassword),
            LoginRecoveryLink(isLoading: isLoading),
            const SizedBox(height: AppSpacing.section),
          ],

          // Submit button
          LoginSubmitButton(
              usePassword: usePassword,
              loginWithPassword: loginWithPassword,
              requestOtp: requestOtp,
              isLoading: isLoading),
          const SizedBox(height: AppSpacing.section),
          LoginRegisterLink(isLoading: isLoading),
        ],
      );
}
