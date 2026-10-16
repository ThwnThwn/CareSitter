import 'package:caresitter_customer/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../../domain/payment_outcome.dart';
import '../models/payment_result_details.dart';
import '../models/payment_result_highlight.dart';

class PaymentResultPresentation {
  const PaymentResultPresentation._();
  static PaymentResultDetails details(PaymentOutcome state) {
    return switch (state) {
      PaymentOutcome.success => const PaymentResultDetails(
          icon: Icons.check_rounded,
          iconColor: AppColors.success,
          iconBackground: AppColors.successLight,
          title: 'Thanh toán thành công',
          message:
              'Khoản thanh toán đã được xác nhận. Bạn có thể xem trạng thái mới nhất trong chi tiết lịch hẹn.',
          label: 'ĐÃ XÁC NHẬN',
          labelColor: AppColors.success,
          labelBackground: AppColors.successLight,
          highlights: [
            PaymentResultHighlight(Icons.verified_user_outlined,
                'CareSitter đã ghi nhận khoản thanh toán của bạn.'),
            PaymentResultHighlight(Icons.person_search_outlined,
                'Theo dõi người chăm sóc và tiến độ ca trong lịch hẹn.'),
          ],
        ),
      PaymentOutcome.syncing => const PaymentResultDetails(
          icon: Icons.sync_rounded,
          iconColor: AppColors.info,
          iconBackground: AppColors.infoLight,
          title: 'Đang xác nhận thanh toán',
          message:
              'Hệ thống đang kiểm tra giao dịch với cổng thanh toán. Lịch hẹn sẽ được cập nhật sau khi xác nhận.',
          label: 'ĐANG ĐỒNG BỘ',
          labelColor: AppColors.info,
          labelBackground: AppColors.infoLight,
          highlights: [
            PaymentResultHighlight(Icons.schedule_outlined,
                'Nếu đã chuyển tiền, hãy chờ xác nhận và kiểm tra lại.'),
            PaymentResultHighlight(Icons.notifications_none_rounded,
                'Bạn có thể mở lại lịch hẹn để xem trạng thái mới nhất.'),
          ],
        ),
      PaymentOutcome.failure => const PaymentResultDetails(
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.error,
          iconBackground: AppColors.errorLight,
          title: 'Thanh toán chưa hoàn tất',
          message:
              'Giao dịch hoặc lịch hẹn đã đóng. Hãy mở chi tiết lịch hẹn để kiểm tra trước khi thanh toán lại.',
          label: 'CẦN THANH TOÁN LẠI',
          labelColor: AppColors.error,
          labelBackground: AppColors.errorLight,
          highlights: [
            PaymentResultHighlight(Icons.lock_outline_rounded,
                'Kiểm tra lịch sử chuyển khoản tại ngân hàng của bạn.'),
            PaymentResultHighlight(Icons.support_agent_outlined,
                'Nếu tiền đã bị trừ, hãy liên hệ hỗ trợ để được đối soát.'),
          ],
        ),
      PaymentOutcome.review => const PaymentResultDetails(
            icon: Icons.support_agent_outlined,
            iconColor: AppColors.info,
            iconBackground: AppColors.infoLight,
            title: 'Giao dịch cần đối soát',
            message:
                'CareSitter cần kiểm tra thêm giao dịch này. Vui lòng chưa thanh toán lại và liên hệ hỗ trợ nếu tiền đã bị trừ.',
            label: 'ĐANG KIỂM TRA',
            labelColor: AppColors.info,
            labelBackground: AppColors.infoLight,
            highlights: [
              PaymentResultHighlight(Icons.receipt_long_outlined,
                  'Giữ lại biên lai chuyển khoản để hỗ trợ đối chiếu.')
            ]),
    };
  }
}
