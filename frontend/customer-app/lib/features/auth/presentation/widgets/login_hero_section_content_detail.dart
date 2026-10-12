import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class LoginHeroSectionContentDetail extends StatelessWidget {
  const LoginHeroSectionContentDetail({super.key});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
        ),
      );
}
