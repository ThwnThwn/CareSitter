import 'package:caregiver_app/app/onboarding/onboarding_status.dart';
import 'package:caregiver_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Màn chào đầu tiên, dựng theo CareSitter Onboarding Screen trên Stitch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.registerRoute,
    required this.loginRoute,
  });

  final String registerRoute;
  final String loginRoute;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _continuing = false;

  Future<void> _open(String route) async {
    if (_continuing) return;
    setState(() => _continuing = true);
    try {
      await OnboardingStatus.complete();
    } catch (_) {
      // Nếu bộ nhớ tùy chọn lỗi, người dùng vẫn có thể đăng nhập/đăng ký.
    }
    if (mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.onboardingSky,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            return Column(children: [
              _OnboardingIllustration(
                height: constraints.maxHeight * (compact ? .4 : .55),
              ),
              Expanded(
                child: _OnboardingSheet(
                  compact: compact,
                  onRegister:
                      _continuing ? null : () => _open(widget.registerRoute),
                  onLogin: _continuing ? null : () => _open(widget.loginRoute),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: Semantics(
          image: true,
          label: 'Người chăm sóc đang đọc sách cùng người cao tuổi',
          child: Image.asset(
            'assets/images/onboarding-illustration.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            excludeFromSemantics: true,
          ),
        ),
      );
}

class _OnboardingSheet extends StatelessWidget {
  const _OnboardingSheet({
    required this.compact,
    required this.onRegister,
    required this.onLogin,
  });

  final bool compact;
  final VoidCallback? onRegister;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x141F3A4D),
              offset: Offset(0, -12),
              blurRadius: 36,
            ),
          ],
        ),
        child: LayoutBuilder(builder: (context, sheet) {
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          final bottomPadding = bottomInset > 0 ? bottomInset + 12 : 24.0;
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 24, 28, bottomPadding),
              child: Column(children: [
                const _OnboardingMessage(),
                SizedBox(height: compact ? 20 : sheet.maxHeight * .22),
                _OnboardingActions(
                  onRegister: onRegister,
                  onLogin: onLogin,
                ),
              ]),
            ),
          );
        }),
      );
}

class _OnboardingActions extends StatelessWidget {
  const _OnboardingActions({required this.onRegister, required this.onLogin});

  final VoidCallback? onRegister;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: onRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.onboardingTeal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.onboardingTeal,
              disabledForegroundColor: Colors.white,
              elevation: 3,
              shadowColor: const Color(0x402BB5A0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: .2,
              ),
            ),
            child: const Text('Bắt đầu ngay'),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onLogin,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.onboardingNavy,
            minimumSize: const Size(48, 44),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: const Text('Tôi đã có tài khoản'),
        ),
      ]);
}

class _OnboardingMessage extends StatelessWidget {
  const _OnboardingMessage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PageMark(active: true),
            SizedBox(width: 8),
            _PageMark(),
            SizedBox(width: 8),
            _PageMark(),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Chăm sóc an tâm ngay tại nhà',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.onboardingNavy,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: const Text(
            'Tìm kiếm người chăm sóc uy tín, tận tâm gần bạn cho người thân yêu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onboardingMuted,
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _PageMark extends StatelessWidget {
  const _PageMark({this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Container(
          width: active ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.onboardingTeal : AppColors.onboardingDot,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}
