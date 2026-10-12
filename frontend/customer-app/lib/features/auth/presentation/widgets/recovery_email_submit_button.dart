import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class RecoveryEmailSubmitButton extends StatelessWidget {
  const RecoveryEmailSubmitButton(
      {super.key,
      required this.busy,
      required this.challenge,
      required this.expired,
      required this.request,
      required this.confirm});
  final bool busy;
  final String? challenge;
  final bool expired;
  final Future<void> Function({bool resend}) request;
  final Future<void> Function() confirm;
  @override
  Widget build(BuildContext context) => FilledButton(
      onPressed: busy || (challenge != null && expired)
          ? null
          : challenge == null
              ? request
              : confirm,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.inset),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(
                  challenge == null ? 'Gửi mã xác minh' : 'Xác minh email')));
}
