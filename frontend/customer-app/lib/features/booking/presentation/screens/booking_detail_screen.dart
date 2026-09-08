import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/navigation_helpers.dart';
import '../../../../core/theme/app_theme.dart';
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
    final statusConfig = _getStatusConfig(booking.status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết lịch hẹn'),
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: const Color(0x1A2F7F7F),
        leading: const AppBackButton(fallbackRoute: '/bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(context, ref, booking),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            FadeSlideStaggered(
              index: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: statusConfig['bg'] as Color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: (statusConfig['color'] as Color).withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color:
                            (statusConfig['color'] as Color).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                          child: Text(statusConfig['emoji'] as String,
                              style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusConfig['label'] as String,
                          style: TextStyle(
                            color: statusConfig['color'] as Color,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Mã đặt lịch: ${booking.id.toUpperCase()}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Caregiver info
            FadeSlideStaggered(
              index: 1,
              child: _buildInfoCard(
                title: 'Người chăm sóc',
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                          booking.caregiverAvatar ?? booking.caregiverInitials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(booking.caregiverName ?? 'Người chăm sóc',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          const Row(
                            children: [
                              Icon(Icons.star,
                                  size: 13, color: Color(0xFFF39C12)),
                              SizedBox(width: 3),
                              Text('4.9 • 127 đánh giá',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '📞 Gọi cho ${booking.caregiverName ?? "người chăm sóc"}...'),
                            backgroundColor: AppColors.primary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.call_outlined,
                          color: AppColors.primary),
                    ),
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '💬 Nhắn tin cho ${booking.caregiverName ?? "người chăm sóc"}...'),
                            backgroundColor: AppColors.primaryLight,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Booking details
            FadeSlideStaggered(
              index: 2,
              child: _buildInfoCard(
                title: 'Thông tin lịch hẹn',
                child: Column(
                  children: [
                    _buildDetailRow(Icons.person_outline, 'Người được chăm sóc',
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
                    _buildDetailRow(
                        Icons.location_on_outlined, 'Địa chỉ', booking.address),
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
                    _buildPaymentRow('Phí nền tảng', 0),
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
                                color: AppColors.textSecondary, fontSize: 13)),
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
                  title: 'Ghi nhận tài chính • Prototype',
                  child: Column(
                    children: [
                      _buildPaymentRow(
                          'Doanh thu nền tảng (15%)', booking.platformRevenue),
                      const Divider(height: 16, color: AppColors.divider),
                      _buildPaymentRow(
                          'Thu nhập caregiver (85%)', booking.caregiverEarning),
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
                    _buildDemoBanner(
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
                  ] else if (booking.status == 'confirmed' ||
                      booking.status == 'assigned') ...[
                    _buildDemoBanner(
                        'Ca đã được nhận. Mô phỏng caregiver đang di chuyển hoặc check-in GPS trực tiếp.'),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => ref
                          .read(bookingStoreProvider.notifier)
                          .caregiverEnRoute(booking.id),
                      icon: const Icon(Icons.directions_car_outlined),
                      label: const Text('Mô phỏng caregiver đang di chuyển'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        backgroundColor: const Color(0xFFE67E22),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => ref
                          .read(bookingStoreProvider.notifier)
                          .caregiverCheckIn(booking.id),
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text('Mô phỏng GPS check-in ngay'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52)),
                    ),
                    const SizedBox(height: 10),
                    _buildCancelButton(context, ref, booking),
                  ] else if (booking.status == 'caregiver_en_route') ...[
                    _buildDemoBanner(
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
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => ref
                          .read(bookingStoreProvider.notifier)
                          .caregiverCheckIn(booking.id),
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text('Mô phỏng GPS check-in'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
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
                      onPressed: () => ref
                          .read(bookingStoreProvider.notifier)
                          .caregiverRequestCheckout(booking.id),
                      icon: const Icon(Icons.logout),
                      label: const Text('Mô phỏng caregiver yêu cầu kết thúc'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _showExtendShiftSheet(context),
                      icon: const Icon(Icons.add_alarm),
                      label: const Text('Gia hạn ca chăm sóc'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                  ] else if (booking.status == 'checkout_pending_review') ...[
                    _buildDemoBanner(
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
                      _buildDemoBanner('Bạn đã đánh giá ca chăm sóc này.'),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/booking/new'),
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Đặt lịch lại'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52)),
                    ),
                  ] else if (booking.status == 'disputed') ...[
                    _buildDemoBanner(
                        'Ca đang được đánh dấu có vấn đề. Prototype tạm dừng ghi nhận tài chính.'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
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

  Widget _buildDemoBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9E7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF39C12).withOpacity(0.3)),
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
    switch (status) {
      case 'in_progress':
        return {
          'label': 'Đang diễn ra',
          'emoji': '🟢',
          'color': const Color(0xFF27AE60),
          'bg': AppColors.primaryContainer
        };
      case 'checkout_pending_review':
        return {
          'label': 'Chờ xác nhận kết thúc',
          'emoji': '🟣',
          'color': const Color(0xFF8E44AD),
          'bg': const Color(0xFFF4ECF7)
        };
      case 'disputed':
        return {
          'label': 'Đang xử lý vấn đề',
          'emoji': '⚠️',
          'color': const Color(0xFFE67E22),
          'bg': const Color(0xFFFEF5E7)
        };
      case 'caregiver_en_route':
        return {
          'label': 'Caregiver đang đến',
          'emoji': '🚗',
          'color': const Color(0xFFE67E22),
          'bg': const Color(0xFFFEF5E7)
        };
      case 'pending_payment':
        return {
          'label': 'Chờ thanh toán ký quỹ',
          'emoji': '💳',
          'color': const Color(0xFFE67E22),
          'bg': const Color(0xFFFEF5E7)
        };
      case 'assigned':
        return {
          'label': 'Caregiver đã nhận ca',
          'emoji': '🤝',
          'color': const Color(0xFF2980B9),
          'bg': const Color(0xFFEBF5FB)
        };
      case 'confirmed':
        return {
          'label': 'Đã xác nhận',
          'emoji': '🔵',
          'color': const Color(0xFF2980B9),
          'bg': const Color(0xFFEBF5FB)
        };
      case 'pending':
        return {
          'label': 'Chờ xác nhận',
          'emoji': '🟡',
          'color': const Color(0xFFF39C12),
          'bg': const Color(0xFFFEF9E7)
        };
      case 'completed':
        return {
          'label': 'Đã hoàn thành',
          'emoji': '✅',
          'color': AppColors.textSecondary,
          'bg': AppColors.surface
        };
      case 'cancelled':
        return {
          'label': 'Đã huỷ',
          'emoji': '❌',
          'color': const Color(0xFFE74C3C),
          'bg': const Color(0xFFFDEDEC)
        };
      default:
        return {
          'label': status,
          'emoji': '⚪',
          'color': AppColors.textSecondary,
          'bg': AppColors.surface
        };
    }
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
                border: Border.all(color: AppColors.success.withOpacity(0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nếu bạn không xác nhận, hệ thống sẽ tự động hoàn tất sau 2 giờ kể từ khi ca kết thúc.',
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
            onPressed: () {
              ref
                  .read(bookingStoreProvider.notifier)
                  .confirmCompleted(booking.id);
              Navigator.pop(dCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Đã xác nhận hoàn thành ca! Cảm ơn bạn.'),
                  backgroundColor: AppColors.success,
                  duration: Duration(seconds: 3),
                ),
              );
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
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
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
        await ref
            .read(bookingStoreProvider.notifier)
            .confirmPayment(booking.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '✅ Thanh toán ký quỹ thành công! Lịch hẹn đã được xác nhận.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi xác nhận thanh toán: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    return amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  void _showExtendShiftSheet(BuildContext context) {
    int selectedHours = 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 32 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              const Text('Gia hạn ca chăm sóc',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                  'Yêu cầu sẽ được gửi đến caregiver.\nCa gia hạn bắt đầu ngay sau ca hiện tại.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
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
              Text('Phí ước tính thêm: ~${selectedHours * 120000}đ',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
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
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52)),
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
              if (booking.status == 'pending' || booking.status == 'confirmed')
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
