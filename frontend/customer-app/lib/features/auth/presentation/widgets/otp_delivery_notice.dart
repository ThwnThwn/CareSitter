import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';

class OtpDeliveryNotice extends StatelessWidget {
  const OtpDeliveryNotice({super.key, required this.email});
  final String email;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Xác minh OTP',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.s26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppFontSizes.s14,
                  height: 1.5),
              children: [
                const TextSpan(text: 'Mã xác thực 6 chữ số đã được gửi đến\n'),
                TextSpan(
                  text: email,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
