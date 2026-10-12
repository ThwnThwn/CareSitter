import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class DisputeBookingFmtPanel extends StatelessWidget {
  const DisputeBookingFmtPanel(
      {super.key, required this.refRow, required this.bk, required this.fmt});
  final Widget Function(String, String) refRow;
  final BookingModel bk;
  final String Function(double) fmt;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.inset),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          refRow('Mã lịch hẹn', '#${bk.id.toUpperCase()}'),
          const Divider(height: 16),
          refRow('Người chăm sóc', bk.caregiverName ?? 'Người chăm sóc'),
          const Divider(height: 16),
          refRow('Ngày', bk.date),
          const Divider(height: 16),
          refRow('Tổng tiền', '${fmt(bk.totalPrice)}đ'),
        ]),
      );
}
