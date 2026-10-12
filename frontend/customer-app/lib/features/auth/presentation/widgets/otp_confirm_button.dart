import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class OtpConfirmButton extends StatelessWidget {
  const OtpConfirmButton(
      {super.key,
      required this.otp,
      required this.isVerifying,
      required this.verify});
  final String otp;
  final bool isVerifying;
  final Future<void> Function() verify;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: otp.length == 6 && !isVerifying ? verify : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.border,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.control)),
          ),
          child: isVerifying
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : const Text(
                  'Xác nhận đăng nhập',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: AppFontSizes.s16,
                      fontWeight: FontWeight.w700),
                ),
        ),
      );
}
