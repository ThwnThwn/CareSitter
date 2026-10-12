import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftDetailActiveAction extends StatelessWidget {
  const ShiftDetailActiveAction({super.key, required this.bookingId});
  final String bookingId;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.pushReplacement('/shifts/$bookingId/active'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        child: const Text('Vào ca đang diễn ra',
            style: TextStyle(
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ),
    );
  }
}
