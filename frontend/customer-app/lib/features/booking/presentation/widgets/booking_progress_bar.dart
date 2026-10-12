import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingProgressBar extends StatelessWidget {
  const BookingProgressBar({super.key, required this.progressWidth});
  final double progressWidth;

  @override
  Widget build(BuildContext context) => Positioned(
        top: 14,
        left: 18,
        child: Container(
          height: 2,
          width: progressWidth,
          color: AppColors.primary,
        ),
      );
}
