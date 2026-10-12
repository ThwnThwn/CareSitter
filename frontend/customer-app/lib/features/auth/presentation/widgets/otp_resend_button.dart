import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class OtpResendButton extends StatelessWidget {
  const OtpResendButton(
      {super.key, required this.countdown, required this.resendOtp});
  final int countdown;
  final Future<void> Function() resendOtp;
  @override
  Widget build(BuildContext context) => Center(
        child: countdown > 0
            ? RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppFontSizes.s14),
                  children: [
                    const TextSpan(text: 'Gửi lại sau '),
                    TextSpan(
                      text: '${countdown}s',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )
            : TextButton.icon(
                onPressed: resendOtp,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Gửi lại mã OTP',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
      );
}
