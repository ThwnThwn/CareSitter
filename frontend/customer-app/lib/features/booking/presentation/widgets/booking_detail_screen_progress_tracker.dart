import 'package:caresitter_customer/features/booking/presentation/widgets/booking_progress_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';

class BookingDetailScreenProgressTracker extends StatelessWidget {
  const BookingDetailScreenProgressTracker(
      {super.key, required this.statusConfig, required this.booking});
  final BookingStatusPresentation statusConfig;
  final BookingModel booking;
  @override
  Widget build(BuildContext context) {
    final currentStep = statusConfig.currentStep;

    final steps = [
      {'title': 'Đặt lịch', 'icon': Icons.check},
      {'title': 'Tiếp nhận', 'icon': Icons.handshake_outlined},
      {'title': 'Thực hiện', 'icon': Icons.play_arrow_outlined},
      {'title': 'Hoàn tất', 'icon': Icons.task_alt},
    ];

    final shortId = booking.id.length > 8
        ? booking.id.substring(0, 8).toUpperCase()
        : booking.id.toUpperCase();

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
      child: BookingProgressContent(
          shortId: shortId,
          currentStep: currentStep,
          steps: steps,
          callbackAction1: () {
            Clipboard.setData(ClipboardData(text: booking.id));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📋 Đã sao chép mã đặt lịch'),
                duration: Duration(seconds: 1),
              ),
            );
          }),
    );
  }
}
