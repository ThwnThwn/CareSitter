import '../widgets/brand_intro_logo.dart';
import '../widgets/brand_intro_wordmark.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Brief CareSitter brand reveal shown after a successful customer sign-in.
class BrandIntroScreen extends StatefulWidget {
  const BrandIntroScreen({super.key, this.onFinished});

  @visibleForTesting
  final VoidCallback? onFinished;

  @override
  State<BrandIntroScreen> createState() => _BrandIntroScreenState();
}

class _BrandIntroScreenState extends State<BrandIntroScreen> {
  static const _logoBackground = Color(0xFFF6F7F1);
  bool _reducedMotionHandled = false;
  bool _finished = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reducedMotionHandled || !MediaQuery.of(context).disableAnimations) {
      return;
    }
    _reducedMotionHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    final onFinished = widget.onFinished;
    if (onFinished != null) {
      onFinished();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: _logoBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandIntroLogo(
                  disableAnimations: disableAnimations,
                  onFinished: _finish,
                ),
                const SizedBox(height: AppSpacing.md),
                BrandIntroWordmark(disableAnimations: disableAnimations),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
