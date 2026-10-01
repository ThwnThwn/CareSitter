import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/data/services/google_sign_in_gateway.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/login_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/validators/auth_validators.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/auth_hero_header.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/google_web_button.dart';

// ─── Stitch Design Tokens (Hero Lifestyle) ──────────────────────────────────
// Based on: projects/9685887642498274590 / screen 2c0a8463e7cd41e78008517578edb60b
// Primary Deep:   #006A43
// Primary:        #2D9E6B (botanical green)
// Surface:        #E7FFF1 (mint background)
// Surface Low:    #E1F9EB
// On-Surface:     #0B1F17
// On-Surface Var: #3E4941
// Outline:        #6E7A71
// Outline Var:    #BDCABF

class _HeroTokens {
  static const Color primary = Color(0xFF2D9E6B);
  static const Color primaryDeep = Color(0xFF006A43);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLow = Color(0xFFE1F9EB);
  static const Color background = Color(0xFFE7FFF1);
  static const Color onSurface = Color(0xFF0B1F17);
  static const Color onSurfaceVariant = Color(0xFF3E4941);
  static const Color outline = Color(0xFF6E7A71);
  static const Color outlineVariant = Color(0xFFBDCABF);
}

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
      backgroundColor: _HeroTokens.background,
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
                      color: _HeroTokens.surface,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeHero) const _HeroSection(),
        Container(
          color: _HeroTokens.surface,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _WelcomeHeading(),
              const SizedBox(height: 20),
              if (loginState.errorMessage case final message?) ...[
                AuthErrorBanner(message: message),
                const SizedBox(height: 16),
              ],
              Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: _heroInputTheme(),
                ),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HeroInputField(
                          controller: _emailCtrl,
                          label: 'Email hoặc Số điện thoại',
                          hint: 'nhapten@email.com',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                          validator: AuthValidators.loginEmail,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          enabled: !loginState.isLoading,
                        ),
                        const SizedBox(height: 16),
                        _HeroInputField(
                          controller: _passCtrl,
                          label: 'Mật khẩu',
                          hint: 'Nhập mật khẩu của bạn',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePass,
                          validator: AuthValidators.loginPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          enabled: !loginState.isLoading,
                          onFieldSubmitted: (_) => _login(),
                          suffixIcon: IconButton(
                            tooltip:
                                _obscurePass ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: _HeroTokens.outline,
                            ),
                            onPressed: loginState.isLoading
                                ? null
                                : () => setState(
                                      () => _obscurePass = !_obscurePass,
                                    ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AuxRow(isLoading: loginState.isLoading),
                        const SizedBox(height: 20),
                        _LoginButton(
                          isLoading: loginState.isLoading,
                          onPressed: _login,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _OrDivider(),
              const SizedBox(height: 16),
              _SocialLoginRow(enabled: !loginState.isLoading),
              const SizedBox(height: 16),
              _OtpLoginButton(enabled: !loginState.isLoading),
              const SizedBox(height: 16),
              const _TrustBanner(),
              const SizedBox(height: 20),
            ],
          ),
        ),
        _RegisterFooter(enabled: !loginState.isLoading),
      ],
    );
  }

  static InputDecorationTheme _heroInputTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _HeroTokens.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _HeroTokens.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _HeroTokens.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9FB8AC)),
      labelStyle: const TextStyle(
        fontSize: 14,
        color: _HeroTokens.onSurfaceVariant,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 12,
        color: _HeroTokens.primary,
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: _HeroTokens.outline,
      suffixIconColor: _HeroTokens.outline,
      errorStyle: const TextStyle(fontSize: 12, color: AppColors.error),
    );
  }
}

// ─── Hero Image Section ──────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 270 + topPad,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero lifestyle image
          Positioned.fill(
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuBdZs8HnJiCeklzGb1fp-FfjS1v1n0KzNgKZ9COKpj7PYHRinMo5Z7aAO39hcAaIhJaQZ7GqF7tVuP1WjifjCTbrikR140oMlQc87R4nDrxbeOwjlqVtdwRBVXIFAgwpht7lKoIMw6dUT4HXbU_rcr16HFbndCnr73d7nscE6vfq25dwoyh0wMsLrk8jzUFAUJkHAV0LrfPXX0_7wPdkxsZqptiR0PiRupIN7hDCughZxwIyob9BloB',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.heroGradient,
                ),
                child: const Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),

          // Gradient overlay: dark top → transparent → white bottom
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.45, 1.0],
                  colors: [
                    const Color(0xFF0B1F17).withValues(alpha: 0.60),
                    const Color(0xFF0B1F17).withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.90),
                  ],
                ),
              ),
            ),
          ),

          // White rounded bottom tab
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
            ),
          ),

          // ── Animated tagline chip at bottom ────────────
          Positioned(
            bottom: 40,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _HeroTokens.surfaceLow,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: _HeroTokens.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PulsingDot(),
                  SizedBox(width: 7),
                  Text(
                    'Đồng hành & Chăm sóc tận tâm',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _HeroTokens.primaryDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing Dot ─────────────────────────────────────────────────────────────

class _PulsingDot extends StatelessWidget {
  const _PulsingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _HeroTokens.primary,
      ),
    );
  }
}

// ─── Welcome Heading ─────────────────────────────────────────────────────────

class _WelcomeHeading extends StatelessWidget {
  const _WelcomeHeading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chào mừng trở lại!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _HeroTokens.onSurface,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Đăng nhập để chăm sóc người thân yêu tốt hơn mỗi ngày.',
          style: TextStyle(
            fontSize: 14,
            color: _HeroTokens.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

// ─── Hero Input Field (label above + prefix icon) ────────────────────────────

class _HeroInputField extends StatelessWidget {
  const _HeroInputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.enabled = true,
    this.onFieldSubmitted,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _HeroTokens.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          enabled: enabled,
          onFieldSubmitted: onFieldSubmitted,
          style: const TextStyle(
            fontSize: 14,
            color: _HeroTokens.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

// ─── Aux Row: Remember + Forgot ──────────────────────────────────────────────

class _AuxRow extends StatefulWidget {
  const _AuxRow({required this.isLoading});

  final bool isLoading;

  @override
  State<_AuxRow> createState() => _AuxRowState();
}

class _AuxRowState extends State<_AuxRow> {
  bool _remember = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.isLoading
                ? null
                : () => setState(() => _remember = !_remember),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _remember,
                    onChanged: widget.isLoading
                        ? null
                        : (v) => setState(() => _remember = v ?? true),
                    activeColor: _HeroTokens.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: const BorderSide(
                      color: _HeroTokens.outlineVariant,
                      width: 1.5,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ghi nhớ đăng nhập',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 12,
                      color: _HeroTokens.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: TextButton(
            onPressed: widget.isLoading ? null : () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Quên mật khẩu?',
              textAlign: TextAlign.end,
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _HeroTokens.primaryDeep,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Login Button ────────────────────────────────────────────────────────────

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _HeroTokens.primaryDeep,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              _HeroTokens.primaryDeep.withValues(alpha: 0.55),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
                children: [
                  Text(
                    'Đăng nhập',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}

// ─── Or Divider ──────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: _HeroTokens.outlineVariant.withValues(alpha: 0.5),
            thickness: 1,
          ),
        ),
        const Flexible(
          flex: 3,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Hoặc tiếp tục với',
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(
                fontSize: 12,
                color: _HeroTokens.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: _HeroTokens.outlineVariant.withValues(alpha: 0.5),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

// ─── Social Login Row ────────────────────────────────────────────────────────

class _SocialLoginRow extends ConsumerWidget {
  const _SocialLoginRow({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _buildGoogleButton(ref),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            label: 'Apple',
            icon: const Icon(
              Icons.apple_rounded,
              size: 20,
              color: _HeroTokens.onSurface,
            ),
            enabled: enabled,
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(WidgetRef ref) {
    if (!kIsWeb) {
      return _SocialButton(
        key: const ValueKey('google-sign-in-button'),
        label: 'Google',
        icon: const _GoogleIcon(),
        enabled: enabled,
        onPressed: () =>
            ref.read(loginControllerProvider.notifier).loginWithGoogle(),
      );
    }

    final initialization = ref.watch(googleIdentityInitializationProvider);
    return initialization.when(
      data: (_) => enabled
          ? SizedBox(
              key: const ValueKey('google-sign-in-button'),
              height: 48,
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: buildGoogleWebButton(width: constraints.maxWidth),
                ),
              ),
            )
          : const _SocialButton(
              label: 'Google',
              icon: _GoogleIcon(),
              enabled: false,
            ),
      loading: () => const _SocialButton(
        label: 'Google',
        icon: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        enabled: false,
      ),
      error: (error, _) => Tooltip(
        message: error is GoogleIdentityException
            ? error.message
            : 'Google Sign-In chưa được cấu hình.',
        child: const _SocialButton(
          label: 'Google',
          icon: _GoogleIcon(),
          enabled: false,
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    this.onPressed,
  });

  final String label;
  final Widget icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _HeroTokens.onSurface,
          side: BorderSide(
            color: _HeroTokens.outlineVariant.withValues(alpha: 0.6),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _HeroTokens.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painted Google "G" multicolor ring icon
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFF4285F4),
      Color(0xFF34A853),
      Color(0xFFFBBC05),
      Color(0xFFEA4335),
    ];
    const startAngles = [0.0, 1.57, 3.14, 4.71];
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.5;
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        startAngles[i],
        1.47,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── OTP Login Button ────────────────────────────────────────────────────────

class _OtpLoginButton extends StatelessWidget {
  const _OtpLoginButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: enabled ? () => context.push('/auth/email') : null,
        icon: const Icon(
          Icons.mark_email_read_outlined,
          size: 18,
          color: _HeroTokens.primaryDeep,
        ),
        label: const Text(
          'Đăng nhập bằng mã OTP (Email)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _HeroTokens.primaryDeep,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _HeroTokens.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ─── Trust / Security Banner ─────────────────────────────────────────────────

class _TrustBanner extends StatelessWidget {
  const _TrustBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _HeroTokens.surfaceLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _HeroTokens.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.security_rounded,
            size: 20,
            color: _HeroTokens.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Bảo mật chuẩn y tế & đồng hành phi lâm sàng: ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _HeroTokens.onSurface,
                      height: 1.45,
                    ),
                  ),
                  TextSpan(
                    text: 'Dữ liệu gia đình được mã hóa an toàn 256-bit.',
                    style: TextStyle(
                      fontSize: 11,
                      color: _HeroTokens.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Register Footer ─────────────────────────────────────────────────────────

class _RegisterFooter extends StatelessWidget {
  const _RegisterFooter({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: _HeroTokens.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Chưa có tài khoản?',
            style: TextStyle(
              fontSize: 14,
              color: _HeroTokens.onSurfaceVariant,
            ),
          ),
          TextButton(
            onPressed: enabled ? () => context.push('/auth/register') : null,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Đăng ký ngay',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _HeroTokens.primaryDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
