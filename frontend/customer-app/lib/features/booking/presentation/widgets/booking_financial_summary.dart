import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class BookingFinancialSummary extends StatelessWidget {
  const BookingFinancialSummary(
      {super.key,
      required this.buildInfoCard,
      required this.buildPaymentRow,
      required this.booking});
  final Widget Function({required Widget child, required String title})
      buildInfoCard;
  final Widget Function(String, double) buildPaymentRow;
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.compact),
            FadeSlideStaggered(
              index: 4,
              child: buildInfoCard(
                title: 'Ghi nhận tài chính',
                child: Column(
                  children: [
                    buildPaymentRow(
                        'Doanh thu nền tảng (15%)', booking.platformRevenue),
                    const Divider(height: 16, color: AppColors.divider),
                    buildPaymentRow(
                        'Thu nhập caregiver (85%)', booking.caregiverEarning),
                  ],
                ),
              ),
            ),
          ]);
}
