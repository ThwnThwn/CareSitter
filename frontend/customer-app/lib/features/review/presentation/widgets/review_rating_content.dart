import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ReviewRatingContent extends StatelessWidget {
  const ReviewRatingContent({super.key, required this.rating});
  final int rating;
  @override
  Widget build(BuildContext context) => Center(
          child: Text(
        rating == 0
            ? 'Chọn số sao'
            : [
                '',
                'Tệ 😞',
                'Chưa tốt 😐',
                'Được 🙂',
                'Tốt 😊',
                'Xuất sắc ⭐'
              ][rating],
        style: const TextStyle(
            color: AppColors.textSecondary, fontSize: AppFontSizes.s14),
      ));
}
