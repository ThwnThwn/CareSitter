import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftEnRouteCheckInButton extends StatelessWidget {
  const ShiftEnRouteCheckInButton({
    super.key,
    required this.callbackAction1,
    required this.isBusy,
  });
  final Future<void> Function() callbackAction1;
  final bool isBusy;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isBusy ? null : callbackAction1,
          icon: isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.my_location_rounded,
                  size: 18, color: Colors.white),
          label: Text(
              isBusy ? 'Đang kiểm tra vị trí…' : 'GPS Check-in tại địa điểm',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.inset),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
      );
}
