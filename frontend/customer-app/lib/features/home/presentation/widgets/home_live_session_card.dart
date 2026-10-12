import 'package:caresitter_customer/features/home/presentation/widgets/home_live_session_layout.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class HomeLiveSessionCard extends StatelessWidget {
  const HomeLiveSessionCard(
      {super.key, required this.booking, required this.formatCurrency});
  final BookingModel booking;
  final String Function(double) formatCurrency;
  @override
  Widget build(BuildContext context) {
    final status = booking.presentationStatusAt(DateTime.now());
    final isOngoing = status == 'in_progress';
    final isTracking = isOngoing || status == 'caregiver_en_route';
    final now = DateTime.now();
    final isToday = booking.scheduledStart.year == now.year &&
        booking.scheduledStart.month == now.month &&
        booking.scheduledStart.day == now.day;
    final caregiverName = booking.caregiverName?.trim();
    final schedule = booking.time.replaceAll(' – ', ' - ');
    final sessionDetail = caregiverName == null || caregiverName.isEmpty
        ? schedule
        : '$schedule ($caregiverName)';
    final statusLabel = switch (status) {
      'in_progress' => 'Đang diễn ra',
      'caregiver_en_route' => 'Đang di chuyển',
      'confirmed' || 'caregiver_accepted' => 'Sắp diễn ra',
      _ => 'Sắp diễn ra',
    };
    final title = isOngoing
        ? 'Ca đang diễn ra hôm nay'
        : isToday
            ? 'Ca sắp diễn ra hôm nay'
            : 'Ca sắp tới';
    final accentColor =
        isOngoing ? AppColors.primary : AppColors.secondaryStrong;

    return HomeHoverButton(
      onTap: () => context.push(
        isTracking
            ? '/bookings/${booking.id}/tracking'
            : '/bookings/${booking.id}',
      ),
      child: HomeLiveSessionLayout(
          isOngoing: isOngoing,
          accentColor: accentColor,
          title: title,
          sessionDetail: sessionDetail,
          formatCurrency: formatCurrency,
          booking: booking,
          statusLabel: statusLabel),
    );
  }
}
