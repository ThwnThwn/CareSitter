import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

/// Brief logo reveal shown after a successful customer sign-in.
class BrandIntroScreen extends StatefulWidget {
  const BrandIntroScreen({super.key, this.onFinished});

  @visibleForTesting
  final VoidCallback? onFinished;

  @override
  State<BrandIntroScreen> createState() => _BrandIntroScreenState();
}

class _BrandIntroScreenState extends State<BrandIntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _markScale;
  late final Animation<double> _iconScale;
  late final Animation<Offset> _nameSlide;
  late final Animation<double> _nameOpacity;
  bool _started = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener(_handleStatus);

    _markScale = Tween<double>(begin: 0.38, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.46, curve: Curves.easeOutCubic),
      ),
    );
    _iconScale = Tween<double>(begin: 0.68, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.13, 0.48, curve: Curves.easeOutCubic),
      ),
    );
    _nameSlide = Tween<Offset>(
      begin: const Offset(0, 0.72),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.34, 0.72, curve: Curves.easeOutCubic),
      ),
    );
    _nameOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.34, 0.58, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.of(context).disableAnimations) {
      _controller.removeStatusListener(_handleStatus);
      _controller.value = 1;
      _controller.addStatusListener(_handleStatus);
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
    } else {
      _controller.forward();
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _finish();
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    final onFinished = widget.onFinished;
    if (onFinished != null) {
      onFinished();
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Transform.scale(
                  key: const ValueKey('caresitter-logo-mark-scale'),
                  scale: _markScale.value,
                  child: child,
                ),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ScaleTransition(
                      scale: _iconScale,
                      child: const Icon(
                        Icons.volunteer_activism_rounded,
                        color: Colors.white,
                        size: 39,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.inset),
              ClipRect(
                child: FadeTransition(
                  opacity: _nameOpacity,
                  child: SlideTransition(
                    position: _nameSlide,
                    child: const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Care',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                          TextSpan(
                            text: 'Sitter',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                      key: ValueKey('caresitter-logo-name'),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: AppFontSizes.s26,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
