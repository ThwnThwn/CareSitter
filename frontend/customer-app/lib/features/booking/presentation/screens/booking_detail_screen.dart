import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/navigation_helpers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/api/dio_client.dart' show AppApiException;
import '../../application/booking_store.dart';

import '../../../../core/presentation/widgets/fade_slide_staggered.dart';

class BookingDetailScreen extends ConsumerWidget {
  final String id;

  const BookingDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(bookingStoreProvider).where((b) => b.id == id);
    if (matches.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Không tìm thấy booking')));
    }
    final booking = matches.first;
    // Trạng thái booking là nguồn sự thật. Dữ liệu hồ sơ caregiver chỉ là enrichment
    // và không được phép làm UI quay lại "Đang tìm" sau khi ca đã được nhận.
    final isWaitingCaregiver = booking.status == 'confirmed';
    final statusConfig = isWaitingCaregiver
        ? _waitingCaregiverStatusConfig()
        : _getStatusConfig(booking.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chi tiết lịch hẹn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0B1F17),
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x1A2F7F7F),
        leading: const AppBackButton(fallbackRoute: '/bookings'),
        actions: [
          // Status badge chip in header (matching Stitch)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 11),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusConfig['bg'] as Color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (statusConfig['color'] as Color).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusConfig['color'] as Color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  statusConfig['shortLabel'] as String? ??
                      statusConfig['label'] as String,
                  style: TextStyle(
                    color: statusConfig['color'] as Color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(context, ref, booking),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(bookingStoreProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Progress Tracker Bento (matching Stitch)
              FadeSlideStaggered(
                index: 0,
                child: _buildProgressTracker(context, statusConfig, booking),
              ),
              const SizedBox(height: 16),

              // Hero Caregiver Profile Card (matching Stitch)
              FadeSlideStaggered(
                index: 1,
                child: isWaitingCaregiver
                    ? _buildWaitingCaregiverCard(context)
                    : _buildCaregiverHeroCard(context, booking),
              ),
              const SizedBox(height: 16),

              // Booking details
              FadeSlideStaggered(
                index: 2,
                child: _buildInfoCard(
                  title: 'Thông tin lịch hẹn',
                  child: Column(
                    children: [
                      _buildDetailRow(
                          Icons.person_outline,
                          'Người được chăm sóc',
                          booking.beneficiaryName ?? 'Người thân'),
                      const Divider(height: 16, color: AppColors.divider),
                      _buildDetailRow(Icons.home_repair_service_outlined,
                          'Dịch vụ', booking.serviceName ?? 'Dịch vụ chăm sóc'),
                      const Divider(height: 16, color: AppColors.divider),
                      _buildDetailRow(
                          Icons.calendar_today_outlined, 'Ngày', booking.date),
                      const Divider(height: 16, color: AppColors.divider),
                      _buildDetailRow(Icons.access_time_outlined, 'Thời gian',
                          '${booking.time} (${booking.duration})'),
                      const Divider(height: 16, color: AppColors.divider),
                      _buildDetailRow(Icons.location_on_outlined, 'Địa chỉ',
                          booking.address),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Payment
              FadeSlideStaggered(
                index: 3,
                child: _buildInfoCard(
                  title: 'Thanh toán',
                  child: Column(
                    children: [
                      _buildPaymentRow(
                          'Dịch vụ (${booking.duration})', booking.totalPrice),
                      const Divider(height: 16, color: AppColors.divider),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tổng cộng',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            '${_formatCurrency(booking.totalPrice)}đ',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: AppColors.divider),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hình thức',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              booking.paymentLabel,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (booking.status == 'completed') ...[
                const SizedBox(height: 12),
                FadeSlideStaggered(
                  index: 4,
                  child: _buildInfoCard(
                    title: 'Ghi nhận tài chính',
                    child: Column(
                      children: [
                        _buildPaymentRow('Doanh thu nền tảng (15%)',
                            booking.platformRevenue),
                        const Divider(height: 16, color: AppColors.divider),
                        _buildPaymentRow('Thu nhập caregiver (85%)',
                            booking.caregiverEarning),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Actions
              FadeSlideStaggered(
                index: 5,
                child: Column(
                  children: [
                    if (booking.status == 'pending_payment' ||
                        booking.status == 'pending') ...[
                      _buildStatusBanner(
                          'Đơn đang chờ bạn thanh toán ký quỹ (Escrow) để kích hoạt và thông báo cho người chăm sóc.'),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _handleConfirmPayment(context, ref, booking),
                        icon: const Icon(Icons.payment_rounded),
                        label: Text(
                            'Thanh toán ký quỹ (${_formatCurrency(booking.totalPrice)}đ)'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (booking.status ==
                        'payment_reconciliation_pending') ...[
                      _buildStatusBanner(
                          'Hệ thống đang đối soát giao dịch gần nhất với VNPay. Vui lòng chưa tạo thêm thanh toán để tránh bị trừ tiền hai lần.'),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (booking.status == 'needs_manual_review') ...[
                      _buildStatusBanner(
                          'Giao dịch chưa thể xác minh tự động. Bộ phận vận hành đang kiểm tra và sẽ cập nhật booking sau khi đối chiếu.'),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (isWaitingCaregiver) ...[
                      _buildStatusBanner(
                          'Đã thanh toán ký quỹ. Lịch hẹn đang được gửi sang ứng dụng caregiver để người chăm sóc nhận ca.'),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (booking.status == 'confirmed' ||
                        booking.status == 'caregiver_accepted' ||
                        booking.status == 'assigned') ...[
                      _buildStatusBanner(
                          'Ca đã được nhận. Vui lòng chờ caregiver bắt đầu di chuyển hoặc check-in từ ứng dụng caregiver.'),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (booking.status == 'caregiver_en_route') ...[
                      _buildStatusBanner(
                          'Caregiver đang trên đường đến. Chờ caregiver GPS check-in tại địa điểm.'),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/bookings/${booking.id}/tracking'),
                        icon: const Icon(Icons.my_location_rounded),
                        label: const Text('Xem vị trí trực tiếp 🚗'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: const Color(0xFFE67E22),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (booking.status == 'in_progress') ...[
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/bookings/${booking.id}/tracking'),
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text('Theo dõi ca chăm sóc'),
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52)),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showExtendShiftSheet(context, booking),
                        icon: const Icon(Icons.add_alarm),
                        label: const Text('Gia hạn ca chăm sóc'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                    ] else if (booking.status == 'checkout_pending_review') ...[
                      _buildStatusBanner(
                          'Caregiver đã gửi yêu cầu kết thúc ca. Hãy xác nhận để hoàn tất.'),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _showCompleteShiftDialog(context, ref, booking),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Đã hoàn thành'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/bookings/${booking.id}/dispute'),
                        icon: const Icon(Icons.report_problem_outlined,
                            color: AppColors.error),
                        label: const Text('Có vấn đề với ca chăm sóc',
                            style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52)),
                      ),
                    ] else if (booking.status == 'completed') ...[
                      if (!booking.isReviewed)
                        ElevatedButton.icon(
                          onPressed: () =>
                              context.push('/bookings/${booking.id}/review'),
                          icon: const Icon(Icons.star_outline),
                          label: const Text('Đánh giá dịch vụ'),
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52)),
                        )
                      else
                        _buildStatusBanner('Bạn đã đánh giá ca chăm sóc này.'),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/booking/new'),
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Đặt lịch lại'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52)),
                      ),
                    ] else if (booking.status == 'disputed') ...[
                      _buildStatusBanner(
                          'Ca đang được đánh dấu có vấn đề. Ghi nhận tài chính sẽ chờ xử lý tranh chấp.'),
                    ] else if (booking.status == 'refunded') ...[
                      _buildStatusBanner(
                          'Đã hoàn ${_formatCurrency(booking.totalPrice)}đ vào Ví CareSitter vì chưa tìm được người chăm sóc phù hợp.'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(
          amount == 0 ? 'Miễn phí' : '${_formatCurrency(amount)}đ',
          style: TextStyle(
            color: amount == 0 ? AppColors.success : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9E7),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFF39C12).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined,
              size: 17, color: Color(0xFFF39C12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF7D6608), height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) {
    return OutlinedButton.icon(
      onPressed: () {
        ref.read(bookingStoreProvider.notifier).cancel(booking.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã huỷ booking prototype')),
        );
      },
      icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
      label:
          const Text('Huỷ lịch hẹn', style: TextStyle(color: AppColors.error)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: AppColors.error),
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return {
          'label': 'Đang diễn ra',
          'shortLabel': 'Đang diễn ra',
          'emoji': '🟢',
          'icon': Icons.play_arrow_rounded,
          'color': const Color(0xFF006A43),
          'bg': const Color(0xFFE8F7F0),
          'currentStep': 2,
          'description': 'Ca chăm sóc đang diễn ra theo kế hoạch.',
        };
      case 'checkout_pending_review':
        return {
          'label': 'Chờ xác nhận kết thúc',
          'shortLabel': 'Chờ xác nhận',
          'emoji': '🟣',
          'icon': Icons.rate_review_outlined,
          'color': const Color(0xFF8E44AD),
          'bg': const Color(0xFFF4ECF7),
          'currentStep': 2,
          'description':
              'Người chăm sóc đã gửi yêu cầu kết thúc ca. Vui lòng kiểm tra.',
        };
      case 'disputed':
        return {
          'label': 'Đang xử lý khiếu nại',
          'shortLabel': 'Khiếu nại',
          'emoji': '⚠️',
          'icon': Icons.warning_amber_rounded,
          'color': const Color(0xFFE67E22),
          'bg': const Color(0xFFFEF5E7),
          'currentStep': 2,
          'description':
              'Bộ phận CSKH đang hỗ trợ xử lý khiếu nại cho ca hẹn này.',
        };
      case 'caregiver_en_route':
        return {
          'label': 'Người chăm sóc đang đến',
          'shortLabel': 'Đang đến',
          'emoji': '🚗',
          'icon': Icons.directions_car_outlined,
          'color': const Color(0xFF0284C7),
          'bg': const Color(0xFFE0F2FE),
          'currentStep': 2,
          'description':
              'Người chăm sóc đang trên đường di chuyển đến địa chỉ của bạn.',
        };
      case 'caregiver_accepted':
      case 'assigned':
        return {
          'label': 'Người chăm sóc đã nhận ca',
          'shortLabel': 'Đã nhận ca',
          'emoji': '🤝',
          'icon': Icons.handshake_outlined,
          'color': const Color(0xFF006A43),
          'bg': const Color(0xFFE8F7F0),
          'currentStep': 1,
          'description':
              'Người chăm sóc đã nhận ca hẹn. Sẵn sàng thực hiện nhiệm vụ.',
        };
      case 'confirmed':
        return {
          'label': 'Đã xác nhận đặt lịch',
          'shortLabel': 'Đã xác nhận',
          'emoji': '✅',
          'icon': Icons.verified_outlined,
          'color': const Color(0xFF006A43),
          'bg': const Color(0xFFE8F7F0),
          'currentStep': 1,
          'description': 'Lịch hẹn đã được xác nhận thành công.',
        };
      case 'pending':
      case 'pending_payment':
      case 'draft':
        return {
          'label': 'Chờ thanh toán / xác nhận',
          'shortLabel': 'Chờ xử lý',
          'emoji': '🟡',
          'icon': Icons.schedule,
          'color': const Color(0xFFD97706),
          'bg': const Color(0xFFFEF3C7),
          'currentStep': 0,
          'description': 'Đang chờ hoàn tất thủ tục đặt lịch ca hẹn.',
        };
      case 'payment_reconciliation_pending':
        return {
          'label': 'Đang đối soát thanh toán',
          'shortLabel': 'Đang đối soát',
          'emoji': '🔎',
          'icon': Icons.manage_search_rounded,
          'color': const Color(0xFF0369A1),
          'bg': const Color(0xFFE0F2FE),
          'currentStep': 0,
          'description':
              'Hệ thống đang xác minh trạng thái giao dịch trực tiếp với VNPay.',
        };
      case 'needs_manual_review':
        return {
          'label': 'Cần kiểm tra thanh toán',
          'shortLabel': 'Chờ kiểm tra',
          'emoji': '🛡️',
          'icon': Icons.admin_panel_settings_outlined,
          'color': const Color(0xFFB45309),
          'bg': const Color(0xFFFFF7ED),
          'currentStep': 0,
          'description':
              'Bộ phận vận hành đang kiểm tra giao dịch trước khi xác nhận hoặc hủy booking.',
        };
      case 'completed':
        return {
          'label': 'Đã hoàn tất ca hẹn',
          'shortLabel': 'Hoàn thành',
          'emoji': '✨',
          'icon': Icons.task_alt,
          'color': const Color(0xFF059669),
          'bg': const Color(0xFFD1FAE5),
          'currentStep': 3,
          'description': 'Ca chăm sóc đã kết thúc an toàn và trọn vẹn.',
        };
      case 'crisis':
        return {
          'label': 'Báo động khẩn cấp',
          'shortLabel': 'Khẩn cấp',
          'emoji': '🚨',
          'icon': Icons.emergency,
          'color': const Color(0xFFDC2626),
          'bg': const Color(0xFFFEE2E2),
          'currentStep': 2,
          'description': 'Hệ thống đã nhận tín hiệu hỗ trợ khẩn cấp.',
        };
      case 'refunded':
        return {
          'label': 'Đã hoàn tiền vào Ví CareSitter',
          'shortLabel': 'Đã hoàn tiền',
          'emoji': '↩️',
          'icon': Icons.account_balance_wallet_outlined,
          'color': const Color(0xFF047857),
          'bg': const Color(0xFFD1FAE5),
          'currentStep': -1,
          'description':
              'Không tìm được người chăm sóc phù hợp. Tiền đã được cộng vào Ví CareSitter.',
        };
      case 'cancelled':
        return {
          'label': 'Đã huỷ lịch hẹn',
          'shortLabel': 'Đã huỷ',
          'emoji': '❌',
          'icon': Icons.cancel_outlined,
          'color': const Color(0xFFE74C3C),
          'bg': const Color(0xFFFDEDEC),
          'currentStep': -1,
          'description': 'Lịch hẹn này đã được huỷ.',
        };
      case 'matching_failed':
        return {
          'label': 'Chưa tìm thấy người chăm sóc',
          'shortLabel': 'Chưa ghép được',
          'emoji': '🟡',
          'icon': Icons.person_off_outlined,
          'color': const Color(0xFFD97706),
          'bg': const Color(0xFFFEF3C7),
          'currentStep': 1,
          'description': 'Hiện chưa có người chăm sóc phù hợp nhận ca này.',
        };
      default:
        final formattedLabel = status.replaceAll('_', ' ');
        return {
          'label': formattedLabel.isEmpty
              ? 'Chi tiết ca'
              : formattedLabel[0].toUpperCase() + formattedLabel.substring(1),
          'shortLabel': formattedLabel,
          'emoji': '📋',
          'icon': Icons.info_outline,
          'color': AppColors.primary,
          'bg': const Color(0xFFE8F7F0),
          'currentStep': 1,
          'description': 'Trạng thái hiện tại: $formattedLabel',
        };
    }
  }

  Map<String, dynamic> _waitingCaregiverStatusConfig() => {
        'label': 'Chờ người chăm sóc nhận ca',
        'shortLabel': 'Đang tìm',
        'emoji': '⏳',
        'icon': Icons.hourglass_top,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFEF3C7),
        'currentStep': 1,
        'description':
            'Hệ thống đang điều phối người chăm sóc tốt nhất cho bạn.',
      };

  Widget _buildProgressTracker(
    BuildContext context,
    Map<String, dynamic> statusConfig,
    BookingModel booking,
  ) {
    final currentStep = statusConfig['currentStep'] as int? ?? 1;
    final isCancelled = currentStep == -1;

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFDDE8E3),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1A2E25),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tiến trình dịch vụ',
                style: TextStyle(
                  color: Color(0xFF0B1F17),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: booking.id));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Đã sao chép mã đặt lịch'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mã ca: #$shortId',
                        style: const TextStyle(
                          color: Color(0xFF006A43),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded,
                          size: 12, color: Color(0xFF006A43)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isCancelled) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEDEC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined,
                      color: Color(0xFFE74C3C), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusConfig['description'] as String,
                      style: const TextStyle(
                        color: Color(0xFFC0392B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth - 36;
                final progressWidth =
                    trackWidth * (currentStep.clamp(0, 3) / 3.0);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background track line
                    Positioned(
                      top: 14,
                      left: 18,
                      right: 18,
                      child: Container(
                        height: 2,
                        color: const Color(0xFFE0E6E3),
                      ),
                    ),
                    // Active progress track line
                    Positioned(
                      top: 14,
                      left: 18,
                      child: Container(
                        height: 2,
                        width: progressWidth,
                        color: const Color(0xFF006A43),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(steps.length, (idx) {
                        final isPassed = idx < currentStep;
                        final isActive = idx == currentStep;

                        Color circleBg;
                        Color iconColor;
                        Border? border;

                        if (isPassed) {
                          circleBg = const Color(0xFF006A43);
                          iconColor = Colors.white;
                        } else if (isActive) {
                          circleBg = const Color(0xFF006A43);
                          iconColor = Colors.white;
                          border = Border.all(
                            color: const Color(0xFF8CF8BD),
                            width: 3,
                          );
                        } else {
                          circleBg = const Color(0xFFE0E6E3);
                          iconColor = const Color(0xFF6E7A71);
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: circleBg,
                                shape: BoxShape.circle,
                                border: border,
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF006A43)
                                              .withValues(alpha: 0.25),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Icon(
                                  isPassed
                                      ? Icons.check
                                      : (steps[idx]['icon'] as IconData),
                                  size: 14,
                                  color: iconColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              steps[idx]['title'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : (isPassed
                                        ? FontWeight.w600
                                        : FontWeight.w400),
                                color: isActive
                                    ? const Color(0xFF006A43)
                                    : (isPassed
                                        ? const Color(0xFF0B1F17)
                                        : const Color(0xFF6E7A71)),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            // Current status description banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusConfig['bg'] as Color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    statusConfig['emoji'] as String,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusConfig['description'] as String,
                      style: TextStyle(
                        color: statusConfig['color'] as Color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCaregiverHeroCard(BuildContext context, BookingModel booking) {
    final caregiverName = booking.caregiverName ?? 'Chăm sóc viên';
    final avatarUrl = booking.caregiverAvatar;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFDDE8E3),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1A2E25),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with verified badge (matching Stitch)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: avatarUrl != null && avatarUrl.startsWith('http')
                        ? Image.network(
                            avatarUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildCaregiverInitials(booking),
                          )
                        : _buildCaregiverInitials(booking),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Name, title, and badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caregiverName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B1F17),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Chăm sóc viên CareSitter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF006A43),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (booking.caregiverName == null)
                          const Text(
                            'Thông tin hồ sơ đang cập nhật',
                            style: TextStyle(
                              color: Color(0xFF5A7272),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF0F4F2)),
          const SizedBox(height: 12),
          // Quick Action Buttons (matching Stitch)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('💬 Nhắn tin cho $caregiverName...'),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 17, color: Color(0xFF006A43)),
                        SizedBox(width: 6),
                        Text(
                          'Nhắn tin',
                          style: TextStyle(
                            color: Color(0xFF006A43),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📞 Gọi cho $caregiverName...'),
                        backgroundColor: const Color(0xFF006A43),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF006A43),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF006A43).withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.call, size: 17, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Gọi trực tiếp',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaregiverInitials(BookingModel booking) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          booking.caregiverInitials,
          style: const TextStyle(
            color: Color(0xFF006A43),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingCaregiverCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE8E3), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A1A2E25),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_search_outlined,
                    color: Color(0xFFD97706),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đang tìm chăm sóc viên phù hợp',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B1F17),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Hệ thống đang tìm người gần địa điểm và phù hợp với khung giờ của bạn.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              minHeight: 5,
              backgroundColor: Color(0xFFE8F1ED),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bạn sẽ nhận thông báo ngay khi có người nhận ca.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showCompleteShiftDialog(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 26),
            SizedBox(width: 10),
            Text('Xác nhận hoàn thành', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn xác nhận ca chăm sóc của ${booking.caregiverName} đã hoàn tất?',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textPrimary, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FBF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nếu bạn không xác nhận, hệ thống sẽ tự động hoàn tất sau 24 giờ kể từ khi yêu cầu checkout được gửi.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Chưa',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              Navigator.pop(dCtx);
              AppToast.loading(context, 'Đang xác nhận hoàn tất ca…');
              try {
                await ref
                    .read(bookingStoreProvider.notifier)
                    .confirmCompleted(booking.id);
                if (!context.mounted) return;
                AppToast.success(
                    context, 'Ca chăm sóc đã được xác nhận hoàn tất.');
              } catch (_) {
                if (!context.mounted) return;
                AppToast.error(
                    context, 'Không thể xác nhận lúc này. Vui lòng thử lại.');
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmPayment(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.primary, size: 26),
            SizedBox(width: 10),
            Text('Thanh toán ký quỹ (Escrow)', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Số tiền thanh toán: ${_formatCurrency(booking.totalPrice)}đ',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF5FB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Khoản tiền này sẽ được giữ an toàn trên CareSitter Platform (Escrow) và chỉ giải ngân cho người chăm sóc sau khi ca trực hoàn tất thành công.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Hủy',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Xác nhận thanh toán'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final intent = await ref
            .read(bookingStoreProvider.notifier)
            .createVnPayPayment(booking.id);
        final uri = Uri.tryParse(intent.paymentUrl);
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw Exception('Không mở được trang thanh toán VNPay Sandbox.');
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Đã mở VNPay Sandbox. Sau khi thanh toán, quay lại app để cập nhật trạng thái.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final message = _paymentErrorMessage(e);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.textPrimary,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    }
  }

  String _paymentErrorMessage(Object error) {
    final apiError = error is DioException && error.error is AppApiException
        ? error.error as AppApiException
        : error is AppApiException
            ? error
            : null;
    if (apiError?.code == 'PAYMENT_IN_PROGRESS') {
      final expiresAt = DateTime.tryParse(
        apiError?.details?['expiresAt']?.toString() ?? '',
      )?.toLocal();
      final retryAt = expiresAt == null
          ? ''
          : ' Bạn có thể thử lại lúc ${expiresAt.hour.toString().padLeft(2, '0')}:${expiresAt.minute.toString().padLeft(2, '0')}.';
      return 'Giao dịch trước vẫn đang được xử lý.$retryAt Nếu tab VNPay còn mở, hãy hoàn tất tại đó.';
    }
    return apiError?.message ??
        'Không thể mở cổng thanh toán. Vui lòng thử lại.';
  }

  String _formatCurrency(double amount) {
    return amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }

  void _showExtendShiftSheet(BuildContext context, BookingModel booking) {
    int selectedHours = 1;
    final bookedHours =
        booking.scheduledEnd.difference(booking.scheduledStart).inMinutes / 60;
    final effectiveHourlyRate =
        bookedHours > 0 ? booking.totalPrice / bookedHours : 0.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 32 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Gia hạn ca chăm sóc',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 28),
                    onPressed: selectedHours > 1
                        ? () => setSheetState(() => selectedHours--)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text('$selectedHours giờ',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 28),
                    onPressed: selectedHours < 4
                        ? () => setSheetState(() => selectedHours++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                  'Phí ước tính thêm: ~${_formatCurrency(selectedHours * effectiveHourlyRate)}đ'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '✅ Yêu cầu gia hạn $selectedHours giờ đã được gửi đến caregiver.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                child: const Text('Gửi yêu cầu gia hạn'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreOptions(
    BuildContext context,
    WidgetRef ref,
    BookingModel booking,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.share_outlined, color: AppColors.primary),
                title: const Text('Chia sẻ lịch hẹn'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Đã sao chép thông tin lịch hẹn')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.print_outlined,
                    color: AppColors.textSecondary),
                title: const Text('In hóa đơn'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Tính năng in hóa đơn sẽ sớm ra mắt')),
                  );
                },
              ),
              if (booking.status == 'pending' ||
                  booking.status == 'confirmed' ||
                  booking.status == 'caregiver_accepted')
                ListTile(
                  leading:
                      const Icon(Icons.cancel_outlined, color: AppColors.error),
                  title: const Text('Hủy lịch hẹn',
                      style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Xác nhận hủy'),
                        content: const Text(
                            'Bạn có chắc muốn hủy lịch hẹn này không?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text('Không'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error),
                            onPressed: () {
                              ref
                                  .read(bookingStoreProvider.notifier)
                                  .cancel(booking.id);
                              Navigator.pop(dCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('✅ Đã gửi yêu cầu hủy lịch hẹn'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            },
                            child: const Text('Hủy lịch'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.help_outline,
                    color: AppColors.textSecondary),
                title: const Text('Liên hệ hỗ trợ'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Đang kết nối với bộ phận hỗ trợ...')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
