import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftCardCheckoutNotice extends StatelessWidget {
  const ShiftCardCheckoutNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.control),
        decoration: BoxDecoration(
          color: AppColors.statusPendingBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.statusPending.withValues(alpha: .28),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.pending_actions_rounded,
              size: 18,
              color: AppColors.statusPending,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Đã gửi yêu cầu checkout. Đang chờ khách hàng xác nhận; hệ thống sẽ tự hoàn tất sau 24 giờ nếu không có khiếu nại.',
                style: TextStyle(
                  fontSize: AppFontSizes.s12,
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
}
