import 'package:flutter/material.dart';
import 'shift_tracking_screeninfo_card.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreenInfoRow extends StatelessWidget {
  const ShiftTrackingScreenInfoRow({super.key, required this.bk});
  final BookingModel bk;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ShiftTrackingScreeninfoCard(
            icon: Icons.person_outline_rounded,
            label: 'Người thân',
            value: bk.beneficiaryName ?? 'Người thân',
          ),
        ),
        const SizedBox(width: AppSpacing.compact),
        Expanded(
          child: ShiftTrackingScreeninfoCard(
            icon: Icons.access_time_outlined,
            label: 'Ca làm',
            value: '${bk.time} • ${bk.duration}',
          ),
        ),
      ],
    );
  }
}
