import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreenNotLiveScaffold extends StatelessWidget {
  const ShiftTrackingScreenNotLiveScaffold(
      {super.key,
      required this.notLiveInfo,
      required this.presentationStatus,
      required this.bk});
  final ({String actionLabel, IconData icon, String message, String title})
      Function(String) notLiveInfo;
  final String presentationStatus;
  final BookingModel bk;
  @override
  Widget build(BuildContext context) {
    final info = notLiveInfo(presentationStatus);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Theo dõi ca chăm sóc',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.w700)),
        leading: const AppBackButton(
          fallbackRoute: AppRoutes.bookings,
          color: AppColors.textPrimary,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(info.icon, size: 56, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                info.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: AppFontSizes.s18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                info.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: AppFontSizes.s14,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => popOrGo(context,
                    fallbackRoute: AppRoutes.bookingDetail(bk.id)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control)),
                ),
                child: Text(info.actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
