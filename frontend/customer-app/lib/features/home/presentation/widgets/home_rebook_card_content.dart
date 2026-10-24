import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_caregiver_avatar.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class HomeRebookCardContent extends StatelessWidget {
  const HomeRebookCardContent(
      {super.key,
      required this.initials,
      required this.name,
      required this.booking,
      required this.callbackAction1});
  final String initials;
  final String name;
  final BookingModel booking;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BookingCaregiverAvatar(
                radius: 24,
                avatarUrl: booking.caregiverAvatar,
                initials: initials,
              ),
              const Spacer(),
              const Icon(Icons.verified_rounded,
                  color: AppColors.primary, size: 14),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.s12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 7, vertical: AppSpacing.tiny),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              booking.serviceName ?? 'Chăm sóc',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          HomeHoverButton(
            onTap: callbackAction1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.compact),
              ),
              child: const Text(
                'Đặt lại',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
}
