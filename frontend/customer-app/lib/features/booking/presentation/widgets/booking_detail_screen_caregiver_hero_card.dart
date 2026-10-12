import 'package:caresitter_customer/features/booking/presentation/widgets/booking_caregiver_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingDetailScreenCaregiverHeroCard extends StatelessWidget {
  const BookingDetailScreenCaregiverHeroCard(
      {super.key, required this.booking, required this.buildCaregiverInitials});
  final BookingModel booking;
  final Widget Function(BookingModel) buildCaregiverInitials;
  @override
  Widget build(BuildContext context) {
    final caregiverName = booking.caregiverName ?? 'Chăm sóc viên';
    final avatarUrl = booking.caregiverAvatar;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: BookingCaregiverContent(
          avatarUrl: avatarUrl,
          buildCaregiverInitials: buildCaregiverInitials,
          booking: booking,
          caregiverName: caregiverName,
          callbackAction1: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('💬 Nhắn tin cho $caregiverName...'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          callbackAction2: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📞 Gọi cho $caregiverName...'),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );
          }),
    );
  }
}
