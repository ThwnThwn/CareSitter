import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class BookingPaymentSummary extends StatelessWidget {
  const BookingPaymentSummary(
      {super.key,
      required this.buildInfoCard,
      required this.buildPaymentRow,
      required this.booking,
      required this.formatCurrency});
  final Widget Function({required Widget child, required String title})
      buildInfoCard;
  final Widget Function(String, double) buildPaymentRow;
  final BookingModel booking;
  final String Function(double) formatCurrency;
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 3,
        child: buildInfoCard(
          title: 'Thanh toán',
          child: Column(
            children: [
              buildPaymentRow(
                  'Dịch vụ (${booking.duration})', booking.totalPrice),
              const Divider(height: 16, color: AppColors.divider),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng cộng',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFontSizes.s15,
                          fontWeight: FontWeight.w700)),
                  Text(
                    '${formatCurrency(booking.totalPrice)}đ',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: AppFontSizes.s18,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const Divider(height: 16, color: AppColors.divider),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hình thức',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSizes.s13)),
                  const SizedBox(width: AppSpacing.compact),
                  Expanded(
                    child: Text(
                      booking.paymentLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: AppFontSizes.s13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
