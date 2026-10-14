import 'booking_detail_screen_detail_row.dart';
import 'booking_detail_screen_info_card.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class BookingAppointmentSummary extends StatelessWidget {
  const BookingAppointmentSummary({super.key, required this.booking});
  final BookingModel booking;
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 2,
        child: BookingDetailScreenInfoCard(
          title: 'Thông tin lịch hẹn',
          child: Column(
            children: [
              BookingDetailScreenDetailRow(
                  icon: Icons.person_outline,
                  label: 'Người được chăm sóc',
                  value: booking.beneficiaryName ?? 'Người thân'),
              const Divider(height: 16, color: AppColors.divider),
              BookingDetailScreenDetailRow(
                  icon: Icons.home_repair_service_outlined,
                  label: 'Dịch vụ',
                  value: booking.serviceName ?? 'Dịch vụ chăm sóc'),
              const Divider(height: 16, color: AppColors.divider),
              BookingDetailScreenDetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Ngày',
                  value: booking.date),
              const Divider(height: 16, color: AppColors.divider),
              BookingDetailScreenDetailRow(
                  icon: Icons.access_time_outlined,
                  label: 'Thời gian',
                  value: '${booking.time} (${booking.duration})'),
              const Divider(height: 16, color: AppColors.divider),
              BookingDetailScreenDetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Địa chỉ',
                  value: booking.address),
            ],
          ),
        ),
      );
}
