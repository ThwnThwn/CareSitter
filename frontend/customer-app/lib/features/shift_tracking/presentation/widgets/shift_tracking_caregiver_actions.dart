import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingCaregiverActions extends StatelessWidget {
  const ShiftTrackingCaregiverActions(
      {super.key,
      required this.callbackAction1,
      required this.callbackAction2});
  final void Function() callbackAction1;
  final void Function() callbackAction2;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: callbackAction1,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Liên hệ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.control),
          ElevatedButton.icon(
            onPressed: callbackAction2,
            icon: const Icon(Icons.emergency_share_outlined, size: 16),
            label: const Text('SOS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.comfortable, vertical: 11),
            ),
          ),
        ],
      );
}
