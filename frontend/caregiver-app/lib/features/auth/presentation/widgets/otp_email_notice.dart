import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class OtpEmailNotice extends StatelessWidget {
  const OtpEmailNotice({super.key, required this.routeEmail});
  final String routeEmail;

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s14,
              height: 1.5),
          children: [
            const TextSpan(text: 'Mã OTP đã được gửi đến\n'),
            TextSpan(
              text: routeEmail,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}
