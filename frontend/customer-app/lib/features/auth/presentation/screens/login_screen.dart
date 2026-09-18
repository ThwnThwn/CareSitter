import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caresitter_customer/core/widgets/app_text_field.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/validators/auth_validators.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/auth_hero_header.dart';

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

    final success = await controller.login(
      email: _emailCtrl.text,
      password: _passCtrl.text,
    );
    if (success && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useWideLayout =
                constraints.maxWidth >= AppBreakpoints.wideAuthLayout &&
                    constraints.maxHeight >= AppBreakpoints.wideAuthMinHeight;

            if (useWideLayout) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(
                    flex: 5,
                    child: FadeSlideStaggered(
                      index: 0,
                      slideFromTop: true,
                      child: AuthHeroHeader(expanded: true),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: LayoutBuilder(
                      builder: (context, formConstraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: formConstraints.maxHeight,
                            ),
                            child: Center(
                              child: _buildFormArea(
                                context,
                                loginState,
                                horizontalPadding: AppSpacing.xl,
                                compact: false,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            final compact = constraints.maxWidth < AppBreakpoints.compact;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    const FadeSlideStaggered(
                      index: 0,
                      slideFromTop: true,
                      child: AuthHeroHeader(),
                    ),
                    _buildFormArea(
                      context,
                      loginState,
                      horizontalPadding: compact
                          ? AppLayout.authPagePaddingCompact
                          : AppLayout.authPagePadding,
                      compact: compact,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormArea(
    BuildContext context,
    LoginState loginState, {
    required double horizontalPadding,
    required bool compact,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppLayout.authFormMaxWidth),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          AppSpacing.xl,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: AppTheme.authInputDecorationTheme,
          ),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideStaggered(
                    index: 1,
                    child: _LoginHeading(compact: compact),
                  ),
                  if (loginState.errorMessage case final message?) ...[
                    FadeSlideStaggered(
                      index: 2,
                      child: AuthErrorBanner(message: message),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  FadeSlideStaggered(
                    index: 2,
                    child: AppTextField(
                      controller: _emailCtrl,
                      label: 'Email',
                      hint: 'example@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: AuthValidators.loginEmail,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      enabled: !loginState.isLoading,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FadeSlideStaggered(
                    index: 3,
                    child: AppTextField(
                      controller: _passCtrl,
                      label: 'Mật khẩu',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscurePass,
                      validator: AuthValidators.loginPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      enabled: !loginState.isLoading,
                      onFieldSubmitted: (_) => _login(),
                      suffixIcon: IconButton(
                        tooltip: _obscurePass ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: loginState.isLoading
                            ? null
                            : () => setState(
                                  () => _obscurePass = !_obscurePass,
                                ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                  FadeSlideStaggered(
                    index: 4,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: loginState.isLoading ? null : () {},
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.xs,
                          ),
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          'Quên mật khẩu?',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FadeSlideStaggered(
                    index: 5,
                    child: _LoginButton(
                      isLoading: loginState.isLoading,
                      onPressed: _login,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                  const FadeSlideStaggered(
                    index: 6,
                    child: _AlternativeDivider(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FadeSlideStaggered(
                    index: 7,
                    child: _OtpLoginButton(
                      enabled: !loginState.isLoading,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                  FadeSlideStaggered(
                    index: 8,
                    child: _RegisterLink(
                      enabled: !loginState.isLoading,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHeading extends StatelessWidget {
  const _LoginHeading({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg + AppSpacing.xs,
        bottom: AppSpacing.lg + AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chào mừng trở lại!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: compact ? 24 : 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.authTextPrimary,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Đăng nhập để tiếp tục chăm sóc người thân',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.authTextSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size.fromHeight(
          AppLayout.authPrimaryButtonMinHeight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      child: isLoading
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.login_rounded, size: 20),
                SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Đăng nhập',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AlternativeDivider extends StatelessWidget {
  const _AlternativeDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.authFieldBorder)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'hoặc',
            style: TextStyle(
              color: AppColors.authTextHint,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.authFieldBorder)),
      ],
    );
  }
}

class _OtpLoginButton extends StatelessWidget {
  const _OtpLoginButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? () => context.push('/auth/email') : null,
      icon: const Icon(
        Icons.mark_email_read_outlined,
        size: 20,
      ),
      label: const Text(
        'Đăng nhập bằng mã OTP (Email)',
        textAlign: TextAlign.center,
        softWrap: true,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(
          AppLayout.authSecondaryButtonMinHeight,
        ),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
    );
  }
}

class _RegisterLink extends StatelessWidget {
  const _RegisterLink({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Chưa có tài khoản?',
          style: TextStyle(
            color: AppColors.authTextSecondary,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: enabled ? () => context.push('/auth/register') : null,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            minimumSize: Size.zero,
          ),
          child: const Text(
            'Đăng ký ngay',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
