import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_section_decoration.dart';
import 'package:flutter/material.dart';

class LoginHeroSection extends StatelessWidget {
  const LoginHeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 270 + topPad,
      child: const LoginHeroSectionDecoration(),
    );
  }
}
