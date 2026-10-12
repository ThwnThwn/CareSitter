import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_caregiver_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreenCaregiverCard extends StatelessWidget {
  const ShiftTrackingScreenCaregiverCard({super.key, required this.bk});
  final BookingModel bk;
  @override
  Widget build(BuildContext context) {
    final caregiverAvatar = bk.caregiverAvatar ?? '';
    final avatarText = caregiverAvatar.isNotEmpty && caregiverAvatar.length <= 3
        ? caregiverAvatar
        : bk.caregiverInitials;
    final statusLabel = bk.status == 'caregiver_en_route'
        ? 'Đang đến'
        : bk.status == 'checkout_pending_review'
            ? 'Chờ duyệt'
            : 'Đang làm';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.9),
      ),
      child: ShiftTrackingCaregiverContent(
          avatarText: avatarText,
          bk: bk,
          statusLabel: statusLabel,
          callbackAction1: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('💬 Kết nối liên hệ với ${bk.caregiverName}...'),
                  backgroundColor: AppColors.primary,
                  duration: const Duration(seconds: 2),
                ),
              ),
          callbackAction2: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('🚨 Đang kích hoạt tín hiệu SOS khẩn cấp 24/7...'),
                  backgroundColor: AppColors.error,
                  duration: Duration(seconds: 3),
                ),
              )),
    );
  }
}
