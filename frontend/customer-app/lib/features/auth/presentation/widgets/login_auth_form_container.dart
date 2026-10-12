import 'package:caresitter_customer/features/auth/presentation/widgets/login_auth_fields.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';

class LoginAuthFormContainer extends StatelessWidget {
  const LoginAuthFormContainer(
      {super.key,
      required this.loginState,
      required this.heroInputTheme,
      required this.formKey,
      required this.emailCtrl,
      required this.passCtrl,
      required this.obscurePass,
      required this.togglePassword,
      required this.login,
      required this.callbackAction1});
  final LoginState loginState;
  final InputDecorationTheme Function() heroInputTheme;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final void Function() togglePassword;
  final Future<void> Function() login;
  final void Function(String) callbackAction1;

  @override
  Widget build(BuildContext context) => Container(
        color: LoginHeroTokens.background,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.section, AppSpacing.section, AppSpacing.section, 0),
        child: LoginAuthFields(
            loginState: loginState,
            heroInputTheme: heroInputTheme,
            formKey: formKey,
            emailCtrl: emailCtrl,
            passCtrl: passCtrl,
            obscurePass: obscurePass,
            callbackAction1: callbackAction1,
            togglePassword: togglePassword,
            login: login),
      );
}
