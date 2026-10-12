import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftEnRouteCheckInButton extends StatelessWidget {
  const ShiftEnRouteCheckInButton({super.key, required this.callbackAction1});
  final Future<void> Function() callbackAction1;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: callbackAction1,
          icon: const Icon(Icons.my_location_rounded,
              size: 18, color: Colors.white),
          label: const Text('GPS Check-in tại địa điểm',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.inset),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
      );
}
