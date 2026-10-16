import 'package:caresitter_customer/features/auth/presentation/widgets/login_screen_auth_content.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';
import '../widgets/login_responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caresitter_customer/core/router/auth_route_redirect.dart';
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
  bool _rememberLogin = true;

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

    final loggedIn = await controller.login(
      email: _emailCtrl.text,
      password: _passCtrl.text,
      rememberSession: _rememberLogin,
    );
    if (!mounted || !loggedIn) return;
    final destination = authRouteRedirect(
      location: GoRouterState.of(context).uri.toString(),
      isAuthenticated: true,
    );
    if (destination != null) context.go(destination);
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
          rememberLogin: _rememberLogin,
          onRememberLoginChanged: (value) =>
              setState(() => _rememberLogin = value),
          login: _login,
          togglePassword: () => setState(() => _obscurePass = !_obscurePass),
        )),
      );
}
