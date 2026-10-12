import 'package:caregiver_app/core/theme/app_spacing.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_metadata.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftCardScheduleMetadata extends StatelessWidget {
  const ShiftCardScheduleMetadata({super.key, required this.shift});
  final ShiftModel shift;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          ShiftMetadata(
            icon: Icons.access_time_rounded,
            label: shift.time,
          ),
          ShiftMetadata(
            icon: Icons.calendar_month_rounded,
            label: shift.date,
          ),
        ],
      );
}
