import 'package:flutter/material.dart';

class HomeHeroImage extends StatelessWidget {
  const HomeHeroImage({super.key});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.75),
              ],
              stops: const [0.3, 1.0],
            ),
          ),
        ),
      );
}
