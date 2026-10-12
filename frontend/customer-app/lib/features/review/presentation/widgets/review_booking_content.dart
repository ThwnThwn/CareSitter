import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class ReviewBookingContent extends StatelessWidget {
  const ReviewBookingContent({super.key, required this.bk});
  final BookingModel bk;
  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 0,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(bk.caregiverAvatar ?? bk.caregiverInitials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: AppFontSizes.s13,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: AppSpacing.compact),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(bk.caregiverName ?? 'Người chăm sóc',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFontSizes.s15,
                          fontWeight: FontWeight.w700)),
                  Text(bk.serviceName ?? 'Dịch vụ chăm sóc',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: AppFontSizes.s13)),
                  Text(bk.date,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: AppFontSizes.s12)),
                ])),
          ]),
        ),
      );
}
