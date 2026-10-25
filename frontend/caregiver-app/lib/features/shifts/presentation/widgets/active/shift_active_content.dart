import 'package:flutter/material.dart';

import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_active_overview.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_checkin_flow.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/active/shift_checklist.dart';

class ShiftActiveContent extends StatelessWidget {
  const ShiftActiveContent({
    super.key,
    required this.booking,
    required this.checkedIn,
    required this.onRetry,
    this.error,
  });

  final ShiftModel booking;
  final bool checkedIn;
  final VoidCallback onRetry;
  final String? error;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.compact,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null) ...[
              _LoadError(message: error!, onRetry: onRetry),
              const SizedBox(height: AppSpacing.compact),
            ],
            if (checkedIn)
              ShiftActiveOverview(booking: booking)
            else
              ShiftCheckinFlow(booking: booking),
            const SizedBox(height: AppSpacing.compact),
            ShiftChecklist(booking: booking),
          ],
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.compact),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: AppFontSizes.s13),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      );
}
