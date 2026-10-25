import 'package:caresitter_customer/features/booking/presentation/widgets/booking_caregiver_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingDetailScreenCaregiverHeroCard extends StatelessWidget {
  const BookingDetailScreenCaregiverHeroCard(
      {super.key, required this.booking});
  final BookingModel booking;
  @override
  Widget build(BuildContext context) {
    final caregiverName = booking.caregiverName ?? 'Chăm sóc viên';
    final avatarUrl = booking.caregiverAvatar;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.comfortable),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Caregiver đồng hành',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.inset),
          BookingCaregiverContent(
              avatarUrl: avatarUrl,
              booking: booking,
              caregiverName: caregiverName,
              callbackAction1: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đang mở trò chuyện với $caregiverName...'),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              callbackAction2: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Đang chuẩn bị cuộc gọi với $caregiverName...'),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }),
        ],
      ),
    );
  }
}
