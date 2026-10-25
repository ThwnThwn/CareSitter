import 'package:caresitter_customer/features/home/presentation/widgets/home_appointment_details.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_appointment_schedule.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_appointment_status_badge.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_appointment_caregiver_name.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_appointment_service_label.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_appointment_inline_status.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/router/app_routes.dart';

class HomeAppointmentCard extends StatelessWidget {
  const HomeAppointmentCard(
      {super.key, required this.booking, required this.now});
  final BookingModel booking;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final status = booking.presentationStatusAt(now);
    final isOngoing = status == 'in_progress' || status == 'caregiver_en_route';
    final statusLabel = isOngoing ? 'Đang diễn ra' : 'Sắp diễn ra';
    final statusColor = isOngoing ? AppColors.primary : AppColors.warning;
    final statusBg =
        isOngoing ? AppColors.primaryContainer : AppColors.warningLight;
    final caregiverName = booking.caregiverName?.trim() ?? 'Chăm sóc viên';
    final initials = caregiverName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase())
        .take(2)
        .join();

    // Format date
    const weekdays = [
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'CN'
    ];
    final dt = booking.scheduledStart;
    final dayLabel =
        dt.year == now.year && dt.month == now.month && dt.day == now.day
            ? 'Hôm nay'
            : weekdays[dt.weekday - 1];
    final dateStr =
        '$dayLabel, ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final compactLayout = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;

    final statusBadge = HomeAppointmentStatusBadge(
        statusBg: statusBg, statusLabel: statusLabel, statusColor: statusColor);

    Widget appointmentDetails({required bool includeStatus}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            HomeAppointmentCaregiverName(caregiverName: caregiverName),
            const SizedBox(height: AppSpacing.tiny),
            HomeAppointmentSchedule(dateStr: dateStr, booking: booking),
            if (booking.serviceName != null)
              HomeAppointmentServiceLabel(booking: booking),
            if (includeStatus)
              HomeAppointmentInlineStatus(statusBadge: statusBadge),
          ],
        );

    return HomeHoverButton(
      onTap: () => context.push(
        isOngoing
            ? AppRoutes.bookingTracking(booking.id)
            : AppRoutes.bookingDetail(booking.id),
      ),
      child: HomeAppointmentDetails(
          appointmentDetails: appointmentDetails,
          initials: initials,
          avatarUrl: booking.caregiverAvatar,
          compactLayout: compactLayout,
          statusBadge: statusBadge),
    );
  }
}
