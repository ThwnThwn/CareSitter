import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreenInfoRow extends StatelessWidget {
  const ShiftTrackingScreenInfoRow(
      {super.key, required this.infoCard, required this.bk});
  final Widget Function(
      {required IconData icon,
      required String label,
      required String subtext,
      required String value}) infoCard;
  final BookingModel bk;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: infoCard(
            icon: Icons.person_outline_rounded,
            label: 'Người thân',
            value: bk.beneficiaryName ?? 'Người thân',
            subtext: 'Thông tin người được chăm sóc',
          ),
        ),
        const SizedBox(width: AppSpacing.compact),
        Expanded(
          child: infoCard(
            icon: Icons.access_time_outlined,
            label: 'Ca làm',
            value: '${bk.time} • ${bk.duration}',
            subtext: bk.date,
          ),
        ),
      ],
    );
  }
}
