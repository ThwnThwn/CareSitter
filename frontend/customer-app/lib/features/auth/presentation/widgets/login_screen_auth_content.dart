import 'package:caresitter_customer/features/auth/presentation/widgets/login_auth_fields.dart';
import 'login_hero_tokens.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_register_footer.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';

class LoginScreenAuthContent extends StatelessWidget {
  const LoginScreenAuthContent(
      {super.key,
      required this.loginState,
      required this.formKey,
      required this.emailCtrl,
      required this.passCtrl,
      required this.obscurePass,
      required this.rememberLogin,
      required this.onRememberLoginChanged,
      required this.login,
      required this.togglePassword});
  final LoginState loginState;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final bool rememberLogin;
  final ValueChanged<bool> onRememberLoginChanged;
  final Future<void> Function() login;
  final VoidCallback togglePassword;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
            color: LoginHeroTokens.background,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.section, AppSpacing.section, AppSpacing.section, 0),
            child: LoginAuthFields(
                loginState: loginState,
                formKey: formKey,
                emailCtrl: emailCtrl,
                passCtrl: passCtrl,
                obscurePass: obscurePass,
                rememberLogin: rememberLogin,
                onRememberLoginChanged: onRememberLoginChanged,
                togglePassword: togglePassword,
                login: login)),
        LoginRegisterFooter(enabled: !loginState.isLoading),
      ],
    );
  }
}
