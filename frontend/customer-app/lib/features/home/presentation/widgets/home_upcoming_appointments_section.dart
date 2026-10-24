import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class HomeUpcomingAppointmentsSection extends StatelessWidget {
  const HomeUpcomingAppointmentsSection(
      {super.key, required this.bookings, required this.buildAppointmentCard});
  final List<BookingModel> bookings;
  final Widget Function(BookingModel, DateTime, BuildContext)
      buildAppointmentCard;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const upcomingStatuses = {
      'confirmed',
      'caregiver_accepted',
      'caregiver_en_route',
      'in_progress',
    };
    final upcoming = bookings
        .where((b) =>
            upcomingStatuses.contains(b.presentationStatusAt(now)) &&
            b.scheduledEnd.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

    final preview = upcoming.take(2).toList();
    if (preview.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Lịch hẹn gần đây',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppFontSizes.s17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            HomeHoverButton(
              onTap: () => context.push(AppRoutes.bookings),
              child: const Text(
                'Xem tất cả',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.inset),
        Column(
          children: [
            for (var i = 0; i < preview.length; i++) ...[
              buildAppointmentCard(preview[i], now, context),
              if (i != preview.length - 1)
                const SizedBox(height: AppSpacing.control),
            ],
          ],
        ),
      ],
    );
  }
}
