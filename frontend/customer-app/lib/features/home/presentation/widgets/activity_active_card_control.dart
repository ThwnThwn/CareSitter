import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ActivityActiveCardControl extends StatelessWidget {
  const ActivityActiveCardControl({super.key, required this.onTrackBooking});
  final void Function() onTrackBooking;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTrackBooking,
          icon: const Icon(Icons.location_on_rounded, size: 18),
          label: const Text('Theo dõi ca chăm sóc'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.compact),
            textStyle: const TextStyle(
                fontSize: AppFontSizes.s14, fontWeight: FontWeight.w700),
          ),
        ),
      );
}
