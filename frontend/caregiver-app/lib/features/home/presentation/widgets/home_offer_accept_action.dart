import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class HomeOfferAcceptAction extends StatelessWidget {
  const HomeOfferAcceptAction(
      {super.key,
      required this.isExpired,
      required this.isProcessing,
      required this.runOfferAction,
      required this.booking,
      required this.callbackAction1});
  final bool isExpired;
  final bool isProcessing;
  final Future<void> Function(BuildContext, String,
      {required Future<void> Function() action,
      required String successMessage}) runOfferAction;
  final ShiftModel booking;
  final Future<void> Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Expanded(
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: isExpired || isProcessing
                ? null
                : () => runOfferAction(
                      context,
                      booking.id,
                      successMessage: 'Đã nhận ca. Ca nằm trong lịch sắp tới.',
                      action: callbackAction1,
                    ),
            icon: isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Nhận ca ngay',
                style: GoogleFonts.beVietnamPro(
                  fontSize: AppFontSizes.s15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              elevation: 0,
            ),
          ),
        ),
      );
}
