import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'booking_detail_screen_status_banner.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_completed_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_review_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_payment_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_active_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_en_route_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_resolved_actions.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class BookingStatusActions extends StatelessWidget {
  const BookingStatusActions(
      {super.key,
      required this.status,
      required this.onPay,
      required this.booking,
      required this.cancelButton,
      required this.isWaitingCaregiver,
      required this.onTrack,
      required this.onExtend,
      required this.onComplete,
      required this.onDispute,
      required this.onReview,
      required this.onRebook});
  final String status;
  final void Function() onPay;
  final BookingModel booking;
  final Widget cancelButton;
  final bool isWaitingCaregiver;
  final void Function() onTrack;
  final void Function() onExtend;
  final void Function() onComplete;
  final void Function() onDispute;
  final void Function() onReview;
  final void Function() onRebook;

  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 5,
        child: Column(
          children: [
            if (status == 'pending_payment' || status == 'pending')
              BookingPaymentActions(
                onPay: onPay,
                booking: booking,
                cancelButton: cancelButton,
              )
            else if (status == 'payment_reconciliation_pending') ...[
              const BookingDetailScreenStatusBanner(
                  message:
                      'Hệ thống đang đối soát giao dịch gần nhất với cổng thanh toán. Vui lòng chưa tạo thêm thanh toán để tránh bị trừ tiền hai lần.'),
              const SizedBox(height: AppSpacing.control),
              cancelButton,
            ] else if (status == 'needs_manual_review') ...[
              const BookingDetailScreenStatusBanner(
                  message:
                      'Giao dịch chưa thể xác minh tự động. Bộ phận vận hành đang kiểm tra và sẽ cập nhật booking sau khi đối chiếu.'),
              const SizedBox(height: AppSpacing.control),
              cancelButton,
            ] else if (isWaitingCaregiver) ...[
              const BookingDetailScreenStatusBanner(
                  message:
                      'Đã thanh toán ký quỹ. Lịch hẹn đang được gửi sang ứng dụng caregiver để người chăm sóc nhận ca.'),
              const SizedBox(height: AppSpacing.control),
              cancelButton,
            ] else if (status == 'confirmed' ||
                status == 'caregiver_accepted' ||
                status == 'assigned')
              BookingResolvedActions(
                status: status,
                cancelButton: cancelButton,
              )
            else if (status == 'caregiver_en_route')
              BookingEnRouteActions(
                onTrack: onTrack,
                cancelButton: cancelButton,
              )
            else if (status == 'in_progress')
              BookingActiveActions(onTrack: onTrack, onExtend: onExtend)
            else if (status == 'checkout_pending_review')
              BookingCompletedActions(onComplete: onComplete, onDispute: onDispute)
            else if (status == 'completed')
              BookingReviewActions(
                  booking: booking, onReview: onReview, onRebook: onRebook)
            else if (status == 'disputed') ...[
              const BookingDetailScreenStatusBanner(
                  message:
                      'Ca đang được đánh dấu có vấn đề. Ghi nhận tài chính sẽ chờ xử lý tranh chấp.'),
            ] else if (status == 'refunded') ...[
              BookingDetailScreenStatusBanner(
                  message:
                      'Đã hoàn ${formatVnd(booking.totalPrice, suffix: '')}đ vào Ví CareSitter vì chưa tìm được người chăm sóc phù hợp.'),
            ],
          ],
        ),
      );
}
