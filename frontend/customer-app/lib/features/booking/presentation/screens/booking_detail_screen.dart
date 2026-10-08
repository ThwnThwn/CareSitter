import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'payment_checkout_sheet.dart';
import '../../data/repositories/booking_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/router/navigation_helpers.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/core/widgets/confirm_action_dialog.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';

import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';

class BookingDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const BookingDetailScreen({super.key, required this.id});

  @override
  ConsumerState<BookingDetailScreen> createState() =>
      _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _isCancelling = false;
  bool _cancelDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final matches =
        ref.watch(bookingStoreProvider).where((b) => b.id == widget.id);
    if (matches.isEmpty) {
      return const Scaffold(
          body: Center(child: Text('Không tìm thấy booking')));
    }
    final booking = matches.first;
    final now = DateTime.now();
    final status = booking.presentationStatusAt(now);
    final statusConfig = BookingStatusPresentation.forBooking(booking, now: now);
    final isWaitingCaregiver = statusConfig.isWaitingCaregiver;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chi tiết lịch hẹn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.shadow,
        leading: const AppBackButton(fallbackRoute: '/bookings'),
        actions: [
          // Status badge chip in header (matching Stitch)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 11),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusConfig.backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusConfig.color.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusConfig.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  statusConfig.label,
                  style: TextStyle(
                    color: statusConfig.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _isCancelling || _cancelDialogOpen
                ? null
                : () => _showMoreOptions(context, ref, booking),
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
              if (status == 'completed') ...[
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
                    if (status == 'pending_payment' || status == 'pending') ...[
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
                    ] else if (status == 'payment_reconciliation_pending') ...[
                      _buildStatusBanner(
                          'Hệ thống đang đối soát giao dịch gần nhất với cổng thanh toán. Vui lòng chưa tạo thêm thanh toán để tránh bị trừ tiền hai lần.'),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (status == 'needs_manual_review') ...[
                      _buildStatusBanner(
                          'Giao dịch chưa thể xác minh tự động. Bộ phận vận hành đang kiểm tra và sẽ cập nhật booking sau khi đối chiếu.'),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (isWaitingCaregiver) ...[
                      _buildStatusBanner(
                          'Đã thanh toán ký quỹ. Lịch hẹn đang được gửi sang ứng dụng caregiver để người chăm sóc nhận ca.'),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (status == 'confirmed' ||
                        status == 'caregiver_accepted' ||
                        status == 'assigned') ...[
                      _buildStatusBanner(
                        status == 'confirmed'
                            ? 'Lịch hẹn đã được xác nhận. Bạn sẽ nhận thông báo khi chăm sóc viên cập nhật tiến trình ca.'
                            : 'Ca đã được nhận. Vui lòng chờ caregiver bắt đầu di chuyển hoặc check-in từ ứng dụng caregiver.',
                      ),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (status == 'caregiver_en_route') ...[
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
                          backgroundColor: AppColors.warning,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildCancelButton(context, ref, booking),
                    ] else if (status == 'in_progress') ...[
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
                    ] else if (status == 'checkout_pending_review') ...[
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
                    ] else if (status == 'completed') ...[
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
                    ] else if (status == 'disputed') ...[
                      _buildStatusBanner(
                          'Ca đang được đánh dấu có vấn đề. Ghi nhận tài chính sẽ chờ xử lý tranh chấp.'),
                    ] else if (status == 'refunded') ...[
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
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined,
              size: 17, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.warning, height: 1.4)),
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
      onPressed: _isCancelling || _cancelDialogOpen
          ? null
          : () => _confirmCancel(booking),
      icon: _isCancelling
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cancel_outlined, color: AppColors.error),
      label: Text(_isCancelling ? 'Đang hủy...' : 'Hủy lịch hẹn'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: AppColors.error),
      ),
    );
  }

  Future<void> _confirmCancel(BookingModel booking) async {
    if (_isCancelling || _cancelDialogOpen) return;
    setState(() => _cancelDialogOpen = true);
    try {
      final confirmed = await showConfirmActionDialog(
        context,
        title: 'Hủy lịch hẹn?',
        message: 'Lịch hẹn ngày ${booking.date}, ${booking.time} sẽ bị hủy.\n'
            'Khoản thanh toán (nếu có) vẫn cần được đối soát.',
        confirmLabel: 'Hủy lịch hẹn',
      );
      if (!confirmed || !mounted) return;
      setState(() {
        _cancelDialogOpen = false;
        _isCancelling = true;
      });

      await ref.read(bookingStoreProvider.notifier).cancel(booking.id);
      if (!mounted) return;
      AppToast.success(context, 'Đã hủy lịch hẹn');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(
        context,
        error is AppApiException
            ? error.message
            : 'Không thể hủy lịch hẹn. Vui lòng thử lại.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancelDialogOpen = false;
          _isCancelling = false;
        });
      }
    }
  }

  Widget _buildProgressTracker(
    BuildContext context,
    BookingStatusPresentation statusConfig,
    BookingModel booking,
  ) {
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tiến trình dịch vụ',
                style: TextStyle(
                  color: AppColors.textPrimary,
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
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mã ca: #$shortId',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded,
                          size: 12, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                      color: AppColors.border,
                    ),
                  ),
                  // Active progress track line
                  Positioned(
                    top: 14,
                    left: 18,
                    child: Container(
                      height: 2,
                      width: progressWidth,
                      color: AppColors.primary,
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
                        circleBg = AppColors.primary;
                        iconColor = Colors.white;
                      } else if (isActive) {
                        circleBg = AppColors.primary;
                        iconColor = Colors.white;
                        border = Border.all(
                          color: AppColors.primaryContainer,
                          width: 3,
                        );
                      } else {
                        circleBg = AppColors.border;
                        iconColor = AppColors.textSecondary;
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
                                        color: AppColors.primary
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
                                  ? AppColors.primary
                                  : (isPassed
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary),
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
                        color: AppColors.textPrimary,
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
                        color: AppColors.primary,
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
                              color: AppColors.textSecondary,
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
          const Divider(height: 1, color: AppColors.background),
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
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 17, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Nhắn tin',
                          style: TextStyle(
                            color: AppColors.primary,
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
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
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
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          booking.caregiverInitials,
          style: const TextStyle(
            color: AppColors.primary,
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
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
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
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_search_outlined,
                    color: AppColors.warning,
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
                        color: AppColors.textPrimary,
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
              backgroundColor: AppColors.surfaceVariant,
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
                color: AppColors.primaryContainer,
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
    final intent = await showModalBottomSheet<PaymentIntentModel>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (_) => PaymentCheckoutSheet(booking: booking),
    );
    if (intent == null || !context.mounted) return;
    context.go(Uri(path: '/payment-result', queryParameters: {
      'bookingId': booking.id,
      if (intent.id.isNotEmpty) 'intentId': intent.id,
      'result': 'pending',
    }).toString());
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
    final status = booking.presentationStatusAt(DateTime.now());
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
              if (const {
                'pending',
                'pending_payment',
                'payment_reconciliation_pending',
                'needs_manual_review',
                'confirmed',
                'caregiver_accepted',
                'assigned',
                'caregiver_en_route',
              }.contains(status))
                ListTile(
                  leading:
                      const Icon(Icons.cancel_outlined, color: AppColors.error),
                  title: const Text('Hủy lịch hẹn',
                      style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmCancel(booking);
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
