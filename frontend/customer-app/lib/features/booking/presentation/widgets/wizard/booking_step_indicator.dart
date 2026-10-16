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
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                  child: i == 0
                      ? const SizedBox.shrink()
                      : Container(
                          height: 2,
                          color: i <= step
                              ? AppColors.success
                              : AppColors.divider)),
              AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: AppSpacing.wide,
                  height: AppSpacing.wide,
                  decoration: BoxDecoration(
                      color: i < step
                          ? AppColors.success
                          : i == step
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: i < step
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text('${i + 1}',
                          style: TextStyle(
                              color:
                                  i == step ? Colors.white : AppColors.textHint,
                              fontSize: AppFontSizes.s12,
                              fontWeight: FontWeight.w600))),
              Expanded(
                  child: i == titles.length - 1
                      ? const SizedBox.shrink()
                      : Container(
                          height: 2,
                          color: i < step
                              ? AppColors.success
                              : AppColors.divider)),
            ]),
            const SizedBox(height: AppSpacing.tiny),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.micro),
                child: Text(titles[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color:
                            i == step ? AppColors.primary : AppColors.textHint,
                        fontSize: AppFontSizes.s9,
                        fontWeight:
                            i == step ? FontWeight.w600 : FontWeight.w400))),
          ])),
      ]));
}
