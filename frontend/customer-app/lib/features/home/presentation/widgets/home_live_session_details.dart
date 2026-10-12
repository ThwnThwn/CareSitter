import 'package:caresitter_customer/features/home/presentation/widgets/home_live_session_heading.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_live_session_summary.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class HomeLiveSessionDetails extends StatelessWidget {
  const HomeLiveSessionDetails(
      {super.key,
      required this.accentColor,
      required this.title,
      required this.sessionDetail,
      required this.formatCurrency,
      required this.booking,
      required this.statusLabel});
  final Color accentColor;
  final String title;
  final String sessionDetail;
  final String Function(double) formatCurrency;
  final BookingModel booking;
  final String statusLabel;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.control),
          HomeLiveSessionHeading(
              title: title,
              accentColor: accentColor,
              sessionDetail: sessionDetail),
          const SizedBox(width: AppSpacing.sm),
          HomeLiveSessionSummary(
              formatCurrency: formatCurrency,
              booking: booking,
              statusLabel: statusLabel,
              accentColor: accentColor),
          const SizedBox(width: 5),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textHint,
          ),
        ],
      );
}
