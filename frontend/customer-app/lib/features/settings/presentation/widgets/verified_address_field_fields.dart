import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class VerifiedAddressFieldFields extends StatelessWidget {
  const VerifiedAddressFieldFields({super.key});

  @override
  Widget build(BuildContext context) => const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                SizedBox(width: AppSpacing.tight),
                Expanded(
                  child: Text(
                    'Đã xác minh vị trí từ Geoapify',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFontSizes.s12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ]);
}
