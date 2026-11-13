import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeOfferDeclineAction extends StatelessWidget {
  const HomeOfferDeclineAction(
      {super.key,
      required this.isExpired,
      required this.isProcessing,
      required this.onDecline});
  final bool isExpired;
  final bool isProcessing;
  final Future<void> Function() onDecline;

  @override
  Widget build(BuildContext context) => Expanded(
        child: SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: isExpired || isProcessing ? null : onDecline,
            icon: isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.close_rounded, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Từ chối',
                style: TextStyle(fontFamily: 'Inter',
                  fontSize: AppFontSizes.s15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
      );
}
