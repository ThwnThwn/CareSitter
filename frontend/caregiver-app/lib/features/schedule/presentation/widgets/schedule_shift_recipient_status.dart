import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';
import 'package:caregiver_app/features/schedule/data/models/schedule_slot_model.dart';

class ScheduleShiftRecipientStatus extends StatelessWidget {
  const ScheduleShiftRecipientStatus(
      {super.key,
      required this.shift,
      required this.statusLabel,
      required this.statusColor});
  final TimelineShift shift;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              shift.beneficiaryName,
              style: const TextStyle(
                fontSize: AppFontSizes.s15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          StatusBadge(
            label: statusLabel,
            color: statusColor,
          ),
        ],
      );
}
