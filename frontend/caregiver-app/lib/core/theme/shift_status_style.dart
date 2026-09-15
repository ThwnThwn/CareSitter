import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Nguồn duy nhất map trạng thái ca làm việc → màu + nhãn + icon + background.
///
/// Trước đây logic này bị lặp lại (và lệch nhau) ở home_screen,
/// shift_list_screen và schedule_screen. Gom về một chỗ để đảm bảo
/// mọi màn hình hiển thị nhất quán.
///
/// Palette đồng bộ với Stitch CareSitter Platform Design System semantic colors.
class ShiftStatusStyle {
  final Color color;
  final Color backgroundColor;
  final String label;
  final IconData icon;

  const ShiftStatusStyle._({
    required this.color,
    required this.backgroundColor,
    required this.label,
    required this.icon,
  });

  factory ShiftStatusStyle.of(String status) {
    switch (status) {
      case 'in_progress':
        return const ShiftStatusStyle._(
          color: AppColors.statusInProgress,
          backgroundColor: AppColors.statusInProgressBg,
          label: 'Đang diễn ra',
          icon: Icons.directions_run_rounded,
        );
      case 'confirmed':
      case 'upcoming':
      case 'assigned':
        return const ShiftStatusStyle._(
          color: AppColors.statusConfirmed,
          backgroundColor: AppColors.statusConfirmedBg,
          label: 'Sắp tới',
          icon: Icons.event_available_rounded,
        );
      case 'caregiver_en_route':
        return const ShiftStatusStyle._(
          color: AppColors.statusInProgress,
          backgroundColor: AppColors.statusInProgressBg,
          label: 'Đang di chuyển',
          icon: Icons.navigation_rounded,
        );
      case 'pending':
      case 'open':
      case 'pending_payment':
        return const ShiftStatusStyle._(
          color: AppColors.statusPending,
          backgroundColor: AppColors.statusPendingBg,
          label: 'Chờ phản hồi',
          icon: Icons.hourglass_bottom_rounded,
        );
      case 'checkout_pending_review':
        return const ShiftStatusStyle._(
          color: AppColors.statusPending,
          backgroundColor: AppColors.statusPendingBg,
          label: 'Chờ khách xác nhận',
          icon: Icons.pending_actions_rounded,
        );
      case 'completed':
        return const ShiftStatusStyle._(
          color: AppColors.statusCompleted,
          backgroundColor: AppColors.statusCompletedBg,
          label: 'Hoàn thành',
          icon: Icons.check_circle_rounded,
        );
      case 'cancelled':
        return const ShiftStatusStyle._(
          color: AppColors.statusCancelled,
          backgroundColor: AppColors.statusCancelledBg,
          label: 'Đã huỷ',
          icon: Icons.cancel_rounded,
        );
      default:
        return ShiftStatusStyle._(
          color: AppColors.textHint,
          backgroundColor: AppColors.surfaceVariant,
          label: status,
          icon: Icons.help_outline_rounded,
        );
    }
  }
}
