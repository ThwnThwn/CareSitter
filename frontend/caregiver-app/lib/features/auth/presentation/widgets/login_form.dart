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
      required this.validateIdentifier,
      required this.passwordController,
      required this.obscurePassword,
      required this.validatePassword,
      required this.isLoading,
      required this.loginWithPassword,
      required this.requestOtp,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.callbackAction5});
  final bool usePassword;
  final TextEditingController identifierController;
  final String? Function(String?) validateIdentifier;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final String? Function(String?) validatePassword;
  final bool isLoading;
  final Future<void> Function() loginWithPassword;
  final Future<void> Function() requestOtp;
  final void Function() callbackAction3;
  final void Function() callbackAction4;
  final void Function() callbackAction5;

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
                usePassword: usePassword,
                callbackAction1: callbackAction3,
                callbackAction2: callbackAction4),
          ),
          const SizedBox(height: AppSpacing.section),

          // Email / Phone field
          LoginIdentifierField(
              identifierController: identifierController,
              usePassword: usePassword,
              validateIdentifier: validateIdentifier),
          const SizedBox(height: AppSpacing.md),

          // Password field (nếu usePassword)
          if (usePassword) ...[
            LoginPasswordField(
                passwordController: passwordController,
                obscurePassword: obscurePassword,
                validatePassword: validatePassword,
                callbackAction1: callbackAction5),
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
