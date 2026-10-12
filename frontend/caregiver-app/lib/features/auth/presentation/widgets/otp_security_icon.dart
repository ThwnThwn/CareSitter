import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class OtpSecurityIcon extends StatelessWidget {
  const OtpSecurityIcon({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.s18),
        ),
        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
      );
}
