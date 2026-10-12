import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingWaitingCaregiverContent extends StatelessWidget {
  const BookingWaitingCaregiverContent({super.key});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_search_outlined,
                    color: AppColors.warning,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.inset),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đang tìm chăm sóc viên phù hợp',
                      style: TextStyle(
                        fontSize: AppFontSizes.s15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.tiny),
                    Text(
                      'Hệ thống đang tìm người gần địa điểm và phù hợp với khung giờ của bạn.',
                      style: TextStyle(
                        fontSize: AppFontSizes.s12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.inset),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              minHeight: 5,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Bạn sẽ nhận thông báo ngay khi có người nhận ca.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}
