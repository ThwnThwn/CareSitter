import 'package:caresitter_customer/features/auth/presentation/widgets/login_screen_auth_content.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';
import '../widgets/login_responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';

// Authentication colors inherit the shared landing-page palette.

// ─── Login Screen ────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final controller = ref.read(loginControllerProvider.notifier);
    controller.clearError();
    if (_formKey.currentState?.validate() != true) return;

    await controller.login(
      email: _emailCtrl.text,
      password: _passCtrl.text,
    );
    // A successful auth-state update sends GoRouter through /brand-intro.
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: LoginHeroTokens.background,
        body: LoginResponsiveLayout(
            child: LoginScreenAuthContent(
          loginState: ref.watch(loginControllerProvider),
          formKey: _formKey,
          emailCtrl: _emailCtrl,
          passCtrl: _passCtrl,
          obscurePass: _obscurePass,
          login: _login,
          togglePassword: () => setState(() => _obscurePass = !_obscurePass),
        )),
      );
}
