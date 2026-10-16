import 'package:caresitter_customer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class BookingProgressTrack extends StatelessWidget {
  const BookingProgressTrack({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
        top: 14,
        left: 18,
        right: 18,
        child: Container(
          height: 2,
          color: AppColors.border,
        ),
      );
}
