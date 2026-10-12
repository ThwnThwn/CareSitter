import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingListActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const BookingListActionIconButton(
      {super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          color: Colors.white,
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
    );
  }
}
