import 'booking_payment_row.dart';
import 'booking_detail_screen_info_card.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class BookingFinancialSummary extends StatelessWidget {
  const BookingFinancialSummary({super.key, required this.booking});
  final BookingModel booking;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.compact),
            FadeSlideStaggered(
              index: 4,
              child: BookingDetailScreenInfoCard(
                title: 'Ghi nhận tài chính',
                child: Column(
                  children: [
                    BookingPaymentRow(
                        label: 'Doanh thu nền tảng (15%)',
                        amount: booking.platformRevenue),
                    const Divider(height: 16, color: AppColors.divider),
                    BookingPaymentRow(
                        label: 'Thu nhập caregiver (85%)',
                        amount: booking.caregiverEarning),
                  ],
                ),
              ),
            ),
          ]);
}
