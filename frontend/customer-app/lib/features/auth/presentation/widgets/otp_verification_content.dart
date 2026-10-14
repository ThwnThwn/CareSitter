import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/otp_state.dart';
import 'otp_delivery_notice.dart';
import 'otp_input_row.dart';
import 'otp_error_message.dart';
import 'otp_confirm_button.dart';
import 'otp_resend_button.dart';

class OtpVerificationContent extends StatelessWidget {
  const OtpVerificationContent(
      {super.key,
      required this.flow,
      required this.controllers,
      required this.focusNodes,
      required this.onDigitChanged,
      required this.otp,
      required this.onVerify,
      required this.onResend,
      required this.email});
  final OtpState flow;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(int, String) onDigitChanged;
  final String otp, email;
  final Future<void> Function() onVerify, onResend;

  @override
  Widget build(BuildContext context) => SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          OtpDeliveryNotice(email: email),
          const SizedBox(height: AppSpacing.lg),
          if (flow.error != null) ...[
            OtpErrorMessage(errorMessage: flow.error),
            const SizedBox(height: AppSpacing.lg),
          ],
          OtpInputRow(
              controllers: controllers,
              focusNodes: focusNodes,
              onDigitChanged: onDigitChanged),
          const SizedBox(height: 36),
          OtpConfirmButton(
              otp: otp, isVerifying: flow.verifying, verify: onVerify),
          const SizedBox(height: AppSpacing.lg),
          OtpResendButton(countdown: flow.countdown, resendOtp: onResend),
        ]),
      ));
}
