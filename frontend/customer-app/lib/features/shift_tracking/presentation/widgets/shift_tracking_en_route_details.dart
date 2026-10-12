import 'package:caresitter_customer/features/shift_tracking/presentation/controllers/shift_tracking_state.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingEnRouteDetails extends StatelessWidget {
  const ShiftTrackingEnRouteDetails(
      {super.key, required this.bk, required this.location});
  final BookingModel bk;
  final ShiftTrackingState location;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chăm sóc viên đang đến',
                      style: TextStyle(
                        fontSize: AppFontSizes.s14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.tiny),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: AppFontSizes.s12,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(text: '${bk.caregiverName} · '),
                          TextSpan(
                            text: location.label,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 900),
                builder: (_, v, __) => Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: v),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: v * 0.5),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
}
