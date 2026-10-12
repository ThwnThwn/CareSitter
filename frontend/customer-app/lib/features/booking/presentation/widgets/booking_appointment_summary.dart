import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class BookingAppointmentSummary extends StatelessWidget {
  const BookingAppointmentSummary(
      {super.key,
      required this.buildInfoCard,
      required this.buildDetailRow,
      required this.booking});
  final Widget Function({required Widget child, required String title})
      buildInfoCard;
  final Widget Function(IconData, String, String) buildDetailRow;
  final BookingModel booking;
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 2,
        child: buildInfoCard(
          title: 'Thông tin lịch hẹn',
          child: Column(
            children: [
              buildDetailRow(Icons.person_outline, 'Người được chăm sóc',
                  booking.beneficiaryName ?? 'Người thân'),
              const Divider(height: 16, color: AppColors.divider),
              buildDetailRow(Icons.home_repair_service_outlined, 'Dịch vụ',
                  booking.serviceName ?? 'Dịch vụ chăm sóc'),
              const Divider(height: 16, color: AppColors.divider),
              buildDetailRow(
                  Icons.calendar_today_outlined, 'Ngày', booking.date),
              const Divider(height: 16, color: AppColors.divider),
              buildDetailRow(Icons.access_time_outlined, 'Thời gian',
                  '${booking.time} (${booking.duration})'),
              const Divider(height: 16, color: AppColors.divider),
              buildDetailRow(
                  Icons.location_on_outlined, 'Địa chỉ', booking.address),
            ],
          ),
        ),
      );
}
