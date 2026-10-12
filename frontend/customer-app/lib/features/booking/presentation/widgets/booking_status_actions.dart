import 'package:caresitter_customer/features/booking/presentation/widgets/booking_completed_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_review_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_payment_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_active_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_en_route_actions.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_resolved_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class BookingStatusActions extends StatelessWidget {
  const BookingStatusActions(
      {super.key,
      required this.status,
      required this.buildStatusBanner,
      required this.action2,
      required this.formatCurrency,
      required this.booking,
      required this.buildCancelButton,
      required this.ref,
      required this.isWaitingCaregiver,
      required this.action3,
      required this.action4,
      required this.action5,
      required this.action6,
      required this.action7,
      required this.action8,
      required this.action9});
  final String status;
  final Widget Function(String) buildStatusBanner;
  final void Function() action2;
  final String Function(double) formatCurrency;
  final BookingModel booking;
  final Widget Function(BuildContext, WidgetRef, BookingModel)
      buildCancelButton;
  final WidgetRef ref;
  final bool isWaitingCaregiver;
  final void Function() action3;
  final void Function() action4;
  final void Function() action5;
  final void Function() action6;
  final void Function() action7;
  final void Function() action8;
  final void Function() action9;

  @override
  Widget build(BuildContext context) => FadeSlideStaggered(
        index: 5,
        child: Column(
          children: [
            if (status == 'pending_payment' || status == 'pending')
              BookingPaymentActions(
                  buildStatusBanner: buildStatusBanner,
                  action2: action2,
                  formatCurrency: formatCurrency,
                  booking: booking,
                  buildCancelButton: buildCancelButton,
                  ref: ref)
            else if (status == 'payment_reconciliation_pending') ...[
              buildStatusBanner(
                  'Hệ thống đang đối soát giao dịch gần nhất với cổng thanh toán. Vui lòng chưa tạo thêm thanh toán để tránh bị trừ tiền hai lần.'),
              const SizedBox(height: AppSpacing.control),
              buildCancelButton(context, ref, booking),
            ] else if (status == 'needs_manual_review') ...[
              buildStatusBanner(
                  'Giao dịch chưa thể xác minh tự động. Bộ phận vận hành đang kiểm tra và sẽ cập nhật booking sau khi đối chiếu.'),
              const SizedBox(height: AppSpacing.control),
              buildCancelButton(context, ref, booking),
            ] else if (isWaitingCaregiver) ...[
              buildStatusBanner(
                  'Đã thanh toán ký quỹ. Lịch hẹn đang được gửi sang ứng dụng caregiver để người chăm sóc nhận ca.'),
              const SizedBox(height: AppSpacing.control),
              buildCancelButton(context, ref, booking),
            ] else if (status == 'confirmed' ||
                status == 'caregiver_accepted' ||
                status == 'assigned')
              BookingResolvedActions(
                  buildStatusBanner: buildStatusBanner,
                  status: status,
                  buildCancelButton: buildCancelButton,
                  ref: ref,
                  booking: booking)
            else if (status == 'caregiver_en_route')
              BookingEnRouteActions(
                  buildStatusBanner: buildStatusBanner,
                  action3: action3,
                  buildCancelButton: buildCancelButton,
                  ref: ref,
                  booking: booking)
            else if (status == 'in_progress')
              BookingActiveActions(action4: action4, action5: action5)
            else if (status == 'checkout_pending_review')
              BookingCompletedActions(
                  buildStatusBanner: buildStatusBanner,
                  action6: action6,
                  action7: action7)
            else if (status == 'completed')
              BookingReviewActions(
                  booking: booking,
                  action8: action8,
                  buildStatusBanner: buildStatusBanner,
                  action9: action9)
            else if (status == 'disputed') ...[
              buildStatusBanner(
                  'Ca đang được đánh dấu có vấn đề. Ghi nhận tài chính sẽ chờ xử lý tranh chấp.'),
            ] else if (status == 'refunded') ...[
              buildStatusBanner(
                  'Đã hoàn ${formatCurrency(booking.totalPrice)}đ vào Ví CareSitter vì chưa tìm được người chăm sóc phù hợp.'),
            ],
          ],
        ),
      );
}
