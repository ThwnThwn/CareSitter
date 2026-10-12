import 'package:caresitter_customer/features/auth/presentation/controllers/otp_controller.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/otp_resend_button.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/otp_confirm_button.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/otp_error_message.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class OtpVerificationContent extends StatelessWidget {
  const OtpVerificationContent(
      {super.key,
      required this.ref,
      required this.buildOtpBox,
      required this.otp,
      required this.verify,
      required this.resendOtp,
      required this.routeEmail});
  final WidgetRef ref;
  final Widget Function(int) buildOtpBox;
  final String otp;
  final Future<void> Function() verify;
  final Future<void> Function() resendOtp;
  final String routeEmail;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
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
                    const TextSpan(
                        text: 'Mã xác thực 6 chữ số đã được gửi đến\n'),
                    TextSpan(
                      text: routeEmail,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (ref.watch(otpControllerProvider(routeEmail)).error !=
                  null) ...[
                OtpErrorMessage(
                    errorMessage:
                        ref.watch(otpControllerProvider(routeEmail)).error),
                const SizedBox(height: AppSpacing.lg),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => buildOtpBox(index)),
              ),
              const SizedBox(height: 36),
              OtpConfirmButton(
                  otp: otp,
                  isVerifying:
                      ref.watch(otpControllerProvider(routeEmail)).verifying,
                  verify: verify),
              const SizedBox(height: AppSpacing.lg),
              OtpResendButton(
                  countdown:
                      ref.watch(otpControllerProvider(routeEmail)).countdown,
                  resendOtp: resendOtp),
            ],
          ),
        ),
      );
}
