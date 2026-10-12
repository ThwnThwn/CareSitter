import 'package:caresitter_customer/features/auth/presentation/widgets/email_login_field.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/email_login_error.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/email_login_register_link.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_widgets.dart';

class EmailLoginForm extends StatelessWidget {
  const EmailLoginForm(
      {super.key,
      required this.isCompact,
      required this.formKey,
      required this.errorMessage,
      required this.emailController,
      required this.validateEmail,
      required this.requestOtp,
      required this.isLoading});
  final bool isCompact;
  final GlobalKey<FormState> formKey;
  final String? errorMessage;
  final TextEditingController emailController;
  final String? Function(String?) validateEmail;
  final Future<void> Function() requestOtp;
  final bool isLoading;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(
          isCompact ? AppSpacing.md : AppSpacing.lg,
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Đăng nhập với OTP',
                style: TextStyle(
                  fontSize: AppFontSizes.s24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.tight),
              const Text(
                'Nhập email của bạn để nhận mã xác thực OTP 6 chữ số',
                style: TextStyle(
                  fontSize: AppFontSizes.s14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Error message banner if any
              if (errorMessage != null) ...[
                EmailLoginError(errorMessage: errorMessage),
                const SizedBox(height: AppSpacing.md),
              ],

              // Email input field
              EmailLoginField(
                  emailController: emailController,
                  validateEmail: validateEmail),
              const SizedBox(height: AppSpacing.lg),

              // Button Submit
              AppButton(
                label: 'Gửi mã OTP qua Email',
                onPressed: requestOtp,
                isLoading: isLoading,
                icon: Icons.arrow_forward_rounded,
              ),
              const SizedBox(height: AppSpacing.section),

              // Hoặc đăng nhập bằng mật khẩu
              Center(
                child: TextButton.icon(
                  onPressed: () => context.push('/auth/login'),
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: const Text(
                    'Đăng nhập bằng Mật khẩu',
                    style: TextStyle(
                      fontSize: AppFontSizes.s14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.compact),

              // Link Đăng ký
              const EmailLoginRegisterLink(),
            ],
          ),
        ),
      );
}
