import 'package:flutter/material.dart';

({IconData icon, String title, String message, String actionLabel})
    shiftNotLiveInfo(String status) {
  switch (status) {
    case 'pending':
      return (
        icon: Icons.hourglass_empty_rounded,
        title: 'Ca chưa bắt đầu',
        message:
            'Đang chờ người chăm sóc nhận ca. Bạn có thể theo dõi trực tiếp ngay khi ca bắt đầu.',
        actionLabel: 'Xem chi tiết lịch hẹn',
      );
    case 'confirmed':
    case 'caregiver_accepted':
    case 'caregiver_en_route':
      return (
        icon: Icons.directions_car_rounded,
        title: 'Caregiver chưa bắt đầu di chuyển',
        message:
            'Caregiver chưa khởi động hành trình. Màn hình Live Tracking sẽ tự mở khi họ bắt đầu di chuyển.',
        actionLabel: 'Xem chi tiết lịch hẹn',
      );
    case 'completed':
      return (
        icon: Icons.check_circle_outline_rounded,
        title: 'Ca đã hoàn thành',
        message: 'Ca chăm sóc này đã kết thúc. Xem lại chi tiết và đánh giá.',
        actionLabel: 'Xem chi tiết',
      );
    case 'disputed':
      return (
        icon: Icons.report_problem_outlined,
        title: 'Ca đang được xử lý khiếu nại',
        message:
            'Yêu cầu của bạn đang được xem xét. Xem chi tiết để biết cập nhật.',
        actionLabel: 'Xem chi tiết',
      );
    case 'cancelled':
      return (
        icon: Icons.cancel_outlined,
        title: 'Ca đã bị huỷ',
        message: 'Ca chăm sóc này đã bị huỷ.',
        actionLabel: 'Xem chi tiết',
      );
    default:
      return (
        icon: Icons.info_outline_rounded,
        title: 'Không thể theo dõi ca này',
        message: 'Trạng thái ca hiện không hỗ trợ theo dõi trực tiếp.',
        actionLabel: 'Xem chi tiết',
      );
  }
}
