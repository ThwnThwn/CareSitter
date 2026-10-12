import 'package:flutter/material.dart';

class AuthHeroHeaderResponsiveDecorations extends StatelessWidget {
  const AuthHeroHeaderResponsiveDecorations({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: const Alignment(1.25, -1.25),
          child: FractionallySizedBox(
            widthFactor: 0.42,
            child: _circle(0.07),
          ),
        ),
        Align(
          alignment: const Alignment(-1.18, 1.18),
          child: FractionallySizedBox(
            widthFactor: 0.29,
            child: _circle(0.06),
          ),
        ),
        Align(
          alignment: const Alignment(0.72, 0.68),
          child: FractionallySizedBox(
            widthFactor: 0.15,
            child: _circle(0.08),
          ),
        ),
      ],
    );
  }

  Widget _circle(double opacity) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
