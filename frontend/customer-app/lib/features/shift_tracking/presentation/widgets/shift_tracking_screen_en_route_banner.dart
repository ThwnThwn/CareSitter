import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_en_route_details.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/controllers/shift_tracking_state.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreenEnRouteBanner extends StatelessWidget {
  const ShiftTrackingScreenEnRouteBanner(
      {super.key, required this.bk, required this.location});
  final BookingModel bk;
  final ShiftTrackingState location;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      child: ShiftTrackingEnRouteDetails(bk: bk, location: location),
    );
  }
}
