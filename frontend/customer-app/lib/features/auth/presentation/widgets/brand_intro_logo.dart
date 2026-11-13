import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BrandIntroLogo extends StatelessWidget {
  const BrandIntroLogo({
    super.key,
    required this.disableAnimations,
    required this.onFinished,
  });

  final bool disableAnimations;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    final logo = Semantics(
      image: true,
      label: 'CareSitter - Chăm sóc gia đình',
      child: Image.asset(
        'assets/images/logo.png',
        key: const ValueKey('caresitter-logo-image'),
        width: 188,
        height: 188,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
    return disableAnimations
        ? logo
        : logo
            .animate(onComplete: (_) => onFinished())
            .fadeIn(
              duration: 420.ms,
              curve: Curves.easeOutCubic,
            )
            .scale(
              begin: const Offset(0.84, 0.84),
              duration: 560.ms,
              curve: Curves.easeOutCubic,
            )
            .shimmer(
              delay: 460.ms,
              duration: 680.ms,
              color: Colors.white.withValues(alpha: 0.42),
            );
  }
}
