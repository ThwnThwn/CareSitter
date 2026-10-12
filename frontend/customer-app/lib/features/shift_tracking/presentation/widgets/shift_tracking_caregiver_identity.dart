import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingCaregiverIdentity extends StatelessWidget {
  const ShiftTrackingCaregiverIdentity(
      {super.key,
      required this.avatarText,
      required this.bk,
      required this.statusLabel});
  final String avatarText;
  final BookingModel bk;
  final String statusLabel;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  avatarText,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: AppFontSizes.s16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bk.caregiverName ?? 'Người chăm sóc',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFontSizes.s16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Chăm sóc: ${bk.beneficiaryName ?? "Người thân"}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.s12,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.control, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(statusLabel,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: AppFontSizes.s11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      );
}
