import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/live_tracking_controller.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftEnRouteStatus extends StatelessWidget {
  const ShiftEnRouteStatus(
      {super.key, required this.isThisBooking, required this.tracking});
  final bool isThisBooking;
  final LiveTrackingState tracking;

  @override
  Widget build(BuildContext context) => Text(
        isThisBooking
            ? tracking.message
            : 'Chưa chia sẻ vị trí cho ca này. Gia đình đang chờ vị trí.',
        style: const TextStyle(
            fontSize: AppFontSizes.s13,
            color: AppColors.textSecondary,
            height: 1.4),
      );
}
