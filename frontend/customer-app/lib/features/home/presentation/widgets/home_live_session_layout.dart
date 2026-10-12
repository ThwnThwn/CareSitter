import 'package:caresitter_customer/features/home/presentation/widgets/home_live_session_details.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class HomeLiveSessionLayout extends StatelessWidget {
  const HomeLiveSessionLayout(
      {super.key,
      required this.isOngoing,
      required this.accentColor,
      required this.title,
      required this.sessionDetail,
      required this.formatCurrency,
      required this.booking,
      required this.statusLabel});
  final bool isOngoing;
  final Color accentColor;
  final String title;
  final String sessionDetail;
  final String Function(double) formatCurrency;
  final BookingModel booking;
  final String statusLabel;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.compact, vertical: 11),
        decoration: BoxDecoration(
          color: isOngoing
              ? AppColors.primaryContainer
              : AppColors.secondaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.28),
          ),
        ),
        child: HomeLiveSessionDetails(
            accentColor: accentColor,
            title: title,
            sessionDetail: sessionDetail,
            formatCurrency: formatCurrency,
            booking: booking,
            statusLabel: statusLabel),
      );
}
