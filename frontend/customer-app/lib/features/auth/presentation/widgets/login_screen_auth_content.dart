import 'package:caresitter_customer/features/auth/presentation/widgets/login_auth_form_container.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_section.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_register_footer.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';

class LoginScreenAuthContent extends StatelessWidget {
  const LoginScreenAuthContent(
      {super.key,
      required this.includeHero,
      required this.loginState,
      required this.heroInputTheme,
      required this.formKey,
      required this.emailCtrl,
      required this.passCtrl,
      required this.obscurePass,
      required this.login,
      required this.togglePassword});
  final bool includeHero;
  final LoginState loginState;
  final InputDecorationTheme Function() heroInputTheme;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final Future<void> Function() login;
  final VoidCallback togglePassword;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeHero) const LoginHeroSection(),
        LoginAuthFormContainer(
            loginState: loginState,
            heroInputTheme: heroInputTheme,
            formKey: formKey,
            emailCtrl: emailCtrl,
            passCtrl: passCtrl,
            obscurePass: obscurePass,
            togglePassword: togglePassword,
            login: login,
            callbackAction1: (_) => login()),
        LoginRegisterFooter(enabled: !loginState.isLoading),
      ],
    );
  }
}
