import 'package:flutter/material.dart';

/// Official Google brand asset; preserve its colors and aspect ratio.
class LoginGoogleIcon extends StatelessWidget {
  const LoginGoogleIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/google-g.png',
      width: 20,
      height: 20,
      excludeFromSemantics: true,
    );
  }
}
