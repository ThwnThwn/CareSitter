import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_welcome_heading.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_input_field.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_aux_row.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_login_button.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_or_divider.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_social_login_row.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_otp_login_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';
import 'package:caresitter_customer/features/auth/domain/auth_validators.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/auth_error_banner.dart';

class LoginAuthFields extends StatelessWidget {
  const LoginAuthFields(
      {super.key,
      required this.loginState,
      required this.formKey,
      required this.emailCtrl,
      required this.passCtrl,
      required this.obscurePass,
      required this.rememberLogin,
      required this.onRememberLoginChanged,
      required this.togglePassword,
      required this.login});
  final LoginState loginState;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final bool rememberLogin;
  final ValueChanged<bool> onRememberLoginChanged;
  final void Function() togglePassword;
  final Future<void> Function() login;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LoginWelcomeHeading(),
          const SizedBox(height: AppSpacing.section),
          if (loginState.errorMessage case final message?) ...[
            AuthErrorBanner(message: message),
            const SizedBox(height: AppSpacing.md),
          ],
          _credentialForm(context),
          const SizedBox(height: AppSpacing.section),
          const LoginOrDivider(),
          const SizedBox(height: AppSpacing.md),
          LoginSocialLoginRow(enabled: !loginState.isLoading),
          const SizedBox(height: AppSpacing.md),
          LoginOtpLoginButton(enabled: !loginState.isLoading),
          const SizedBox(height: AppSpacing.section),
        ],
      );

  Widget _credentialForm(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(inputDecorationTheme: _heroInputTheme()),
      child: AutofillGroup(
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LoginHeroInputField(
                controller: emailCtrl,
                label: 'Email hoặc Số điện thoại',
                hint: 'nhapten@email.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.text,
                validator: AuthValidators.loginEmail,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                enabled: !loginState.isLoading,
              ),
              const SizedBox(height: AppSpacing.md),
              LoginHeroInputField(
                controller: passCtrl,
                label: 'Mật khẩu',
                hint: 'Nhập mật khẩu của bạn',
                icon: Icons.lock_outline_rounded,
                obscureText: obscurePass,
                validator: AuthValidators.loginPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !loginState.isLoading,
                onFieldSubmitted: (_) => login(),
                suffixIcon: IconButton(
                  tooltip: obscurePass ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  icon: Icon(
                    obscurePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: LoginHeroTokens.outline,
                  ),
                  onPressed: loginState.isLoading ? null : togglePassword,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              LoginAuxRow(
                isLoading: loginState.isLoading,
                rememberLogin: rememberLogin,
                onRememberLoginChanged: onRememberLoginChanged,
              ),
              const SizedBox(height: AppSpacing.section),
              LoginLoginButton(
                isLoading: loginState.isLoading,
                onPressed: login,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static InputDecorationTheme _heroInputTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.inset),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(
          color: LoginHeroTokens.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(
          color: LoginHeroTokens.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide:
            const BorderSide(color: LoginHeroTokens.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: const TextStyle(
          fontSize: AppFontSizes.s14, color: AppColors.textHint),
      labelStyle: const TextStyle(
        fontSize: AppFontSizes.s14,
        color: LoginHeroTokens.onSurfaceVariant,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: AppFontSizes.s12,
        color: LoginHeroTokens.primary,
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: LoginHeroTokens.outline,
      suffixIconColor: LoginHeroTokens.outline,
      errorStyle:
          const TextStyle(fontSize: AppFontSizes.s12, color: AppColors.error),
    );
  }
}
