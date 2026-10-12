import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

({String label, String subtitle, Color color, Color bgColor, IconData icon})
    shiftDetailStatusInfo(String status) {
  switch (status) {
    case 'confirmed':
    case 'assigned':
      return (
        label: 'Đã xác nhận',
        subtitle: 'Sắp tới ca làm việc của bạn',
        color: AppColors.statusConfirmed,
        bgColor: AppColors.statusConfirmedBg,
        icon: Icons.check_circle_outline_rounded
      );
    case 'pending':
    case 'open':
      return (
        label: 'Chờ phản hồi',
        subtitle: 'Vui lòng nhận hoặc từ chối ca này',
        color: AppColors.statusPending,
        bgColor: AppColors.statusPendingBg,
        icon: Icons.schedule_rounded
      );
    case 'caregiver_en_route':
      return (
        label: 'Đang di chuyển',
        subtitle: 'Chia sẻ vị trí khi mở ứng dụng',
        color: AppColors.statusInProgress,
        bgColor: AppColors.statusInProgressBg,
        icon: Icons.directions_car_rounded
      );
    case 'in_progress':
      return (
        label: 'Đang diễn ra',
        subtitle: 'Ca chăm sóc đang tiến hành',
        color: AppColors.statusInProgress,
        bgColor: AppColors.statusInProgressBg,
        icon: Icons.play_circle_outline_rounded
      );
    case 'completed':
      return (
        label: 'Hoàn thành',
        subtitle: 'Ca đã hoàn tất thành công',
        color: AppColors.statusCompleted,
        bgColor: AppColors.statusCompletedBg,
        icon: Icons.check_circle_rounded
      );
    default:
      return (
        label: 'Không xác định',
        subtitle: '',
        color: AppColors.textHint,
        bgColor: AppColors.surfaceVariant,
        icon: Icons.help_outline_rounded
      );
  }
}
