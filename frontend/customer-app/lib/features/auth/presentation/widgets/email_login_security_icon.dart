import 'package:caresitter_customer/features/auth/presentation/widgets/email_login_brand.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class EmailLoginSecurityIcon extends StatelessWidget {
  const EmailLoginSecurityIcon({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 260),
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(36),
            bottomRight: Radius.circular(36),
          ),
        ),
        child: Stack(
          children: [
            // Background decorative shapes
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: 10,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            const EmailLoginBrand(),
          ],
        ),
      );
}
