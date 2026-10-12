import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingProgressHeader extends StatelessWidget {
  const BookingProgressHeader(
      {super.key, required this.callbackAction1, required this.shortId});
  final void Function() callbackAction1;
  final String shortId;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Tiến trình dịch vụ',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.s14,
              fontWeight: FontWeight.w700,
            ),
          ),
          InkWell(
            onTap: callbackAction1,
            borderRadius: BorderRadius.circular(AppRadius.tight),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.tight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mã ca: #$shortId',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFontSizes.s12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.copy_rounded,
                      size: 12, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      );
}
