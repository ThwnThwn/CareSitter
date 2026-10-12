import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class OtpResendAction extends StatelessWidget {
  const OtpResendAction(
      {super.key,
      required this.countdown,
      required this.isResending,
      required this.resendOtp});
  final int countdown;
  final bool isResending;
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
            : TextButton(
                onPressed: isResending ? null : resendOtp,
                child: Text(
                  isResending ? 'Đang gửi lại...' : 'Gửi lại mã OTP',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
      );
}
