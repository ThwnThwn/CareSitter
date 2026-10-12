import 'package:caresitter_customer/features/auth/presentation/widgets/auth_hero_layout.dart';
import 'package:flutter/material.dart';

class AuthHeroHeader extends StatelessWidget {
  const AuthHeroHeader({
    super.key,
    this.expanded = false,
  });

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final hero = AuthHeroLayout(expanded: expanded);

    return expanded ? SizedBox.expand(child: hero) : hero;
  }
}
