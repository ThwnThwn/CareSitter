import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingStepIndicator extends StatelessWidget {
  const BookingStepIndicator({super.key, required this.step});
  final int step;
  static const titles = [
    'Dịch vụ',
    'Người nhận',
    'Lịch & địa chỉ',
    'Chăm sóc viên',
    'Đồng ý',
    'Xác nhận'
  ];
  @override
  Widget build(BuildContext context) => Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.compact),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < titles.length; i++)
          Expanded(
              child: Column(children: [
            CircleAvatar(
                radius: 14,
                backgroundColor: i < step
                    ? AppColors.success
                    : i == step
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                child: i < step
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text('${i + 1}',
                        style: TextStyle(
                            color:
                                i == step ? Colors.white : AppColors.textHint,
                            fontSize: AppFontSizes.s12))),
            const SizedBox(height: AppSpacing.tiny),
            Text(titles[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: i == step ? AppColors.primary : AppColors.textHint,
                    fontSize: AppFontSizes.s9)),
          ])),
      ]));
}
