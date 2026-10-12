import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_section_content.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_section_content_body.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_section_content_inner.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_section_content_detail.dart';
import 'package:flutter/material.dart';

class LoginHeroSectionDecoration extends StatelessWidget {
  const LoginHeroSectionDecoration({super.key});

  @override
  Widget build(BuildContext context) => const Stack(
        fit: StackFit.expand,
        children: [
          // Hero lifestyle image
          LoginHeroSectionContentBody(),

          // Gradient overlay: dark top → transparent → white bottom
          LoginHeroSectionContentInner(),

          // White rounded bottom tab
          LoginHeroSectionContentDetail(),

          // ── Animated tagline chip at bottom ────────────
          LoginHeroSectionContent(),
        ],
      );
}
