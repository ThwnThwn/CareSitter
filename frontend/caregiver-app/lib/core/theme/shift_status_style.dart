import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Nguồn duy nhất map trạng thái ca làm việc → màu + nhãn + icon.
///
/// Trước đây logic này bị lặp lại (và lệch nhau) ở home_screen,
/// shift_list_screen và schedule_screen. Gom về một chỗ để đảm bảo
/// mọi màn hình hiển thị nhất quán.
class ShiftStatusStyle {
  final Color color;
  final String label;
  final IconData icon;

  const ShiftStatusStyle._({
    required this.color,
    required this.label,
    required this.icon,
  });

  factory ShiftStatusStyle.of(String status) {
    switch (status) {
      case 'in_progress':
        return const ShiftStatusStyle._(
          color: AppColors.success,
          label: 'Đang diễn ra',
          icon: Icons.directions_run_rounded,
        );
      case 'confirmed':
      case 'upcoming':
        return const ShiftStatusStyle._(
          color: AppColors.primary,
          label: 'Sắp tới',
          icon: Icons.event_available_rounded,
        );
      case 'pending':
        return const ShiftStatusStyle._(
          color: AppColors.statusPending,
          label: 'Chờ phản hồi',
          icon: Icons.hourglass_bottom_rounded,
        );
      case 'completed':
        return const ShiftStatusStyle._(
          color: AppColors.info,
          label: 'Hoàn thành',
          icon: Icons.check_circle_rounded,
        );
      case 'cancelled':
        return const ShiftStatusStyle._(
          color: AppColors.error,
          label: 'Đã huỷ',
          icon: Icons.cancel_rounded,
        );
      default:
        return ShiftStatusStyle._(
          color: AppColors.textHint,
          label: status,
          icon: Icons.help_outline_rounded,
        );
    }
  }
}
