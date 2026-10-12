import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftAcceptButton extends StatelessWidget {
  const ShiftAcceptButton({super.key, required this.callbackAction1});
  final Future<void> Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: 2,
        child: ElevatedButton(
          onPressed: callbackAction1,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.inset),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
          child: const Text('Nhận ca',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      );
}
