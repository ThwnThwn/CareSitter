import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class LiveMapPin extends StatelessWidget {
  const LiveMapPin({super.key, required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3)),
        child: Icon(icon, color: Colors.white, size: 22),
      );
}
