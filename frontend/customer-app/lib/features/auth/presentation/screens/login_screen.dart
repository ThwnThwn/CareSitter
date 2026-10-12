import 'package:caresitter_customer/features/auth/presentation/widgets/login_screen_auth_content.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/auth_hero_header.dart';

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
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginControllerProvider);

    return Scaffold(
      backgroundColor: LoginHeroTokens.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useWideLayout =
              constraints.maxWidth >= AppBreakpoints.wideAuthLayout &&
                  constraints.maxHeight >= AppBreakpoints.wideAuthMinHeight;

          if (useWideLayout) {
            return SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(
                    flex: 5,
                    child: AuthHeroHeader(expanded: true),
                  ),
                  Expanded(
                    flex: 6,
                    child: ColoredBox(
                      color: LoginHeroTokens.background,
                      child: LayoutBuilder(
                        builder: (context, formConstraints) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: formConstraints.maxHeight,
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: AppLayout.authFormMaxWidth,
                                  ),
                                  child: _buildAuthContent(
                                    loginState,
                                    includeHero: false,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildAuthContent(loginState, includeHero: true),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAuthContent(
    LoginState loginState, {
    required bool includeHero,
  }) =>
      LoginScreenAuthContent(
          includeHero: includeHero,
          loginState: loginState,
          heroInputTheme: _heroInputTheme,
          formKey: _formKey,
          emailCtrl: _emailCtrl,
          passCtrl: _passCtrl,
          obscurePass: _obscurePass,
          login: _login,
          togglePassword: () => setState(() => _obscurePass = !_obscurePass));

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

// ─── Hero Image Section ──────────────────────────────────────────────────────

// ─── Pulsing Dot ─────────────────────────────────────────────────────────────

// ─── Welcome Heading ─────────────────────────────────────────────────────────

// ─── Hero Input Field (label above + prefix icon) ────────────────────────────

// ─── Aux Row: Remember + Forgot ──────────────────────────────────────────────

// ─── Login Button ────────────────────────────────────────────────────────────

// ─── Or Divider ──────────────────────────────────────────────────────────────

// ─── Social Login Row ────────────────────────────────────────────────────────

// ─── OTP Login Button ────────────────────────────────────────────────────────

// ─── Register Footer ─────────────────────────────────────────────────────────
