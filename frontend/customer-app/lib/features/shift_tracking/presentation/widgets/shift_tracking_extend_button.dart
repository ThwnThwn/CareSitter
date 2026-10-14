import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingExtendButton extends StatelessWidget {
  const ShiftTrackingExtendButton({super.key, required this.onExtendShift});
  final void Function() onExtendShift;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.control),
            OutlinedButton.icon(
              onPressed: onExtendShift,
              icon: const Icon(Icons.more_time_outlined, size: 16),
              label: const Text('Yêu cầu gia hạn ca'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.secondaryStrong,
                side: const BorderSide(color: AppColors.secondaryStrong),
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ]);
}
