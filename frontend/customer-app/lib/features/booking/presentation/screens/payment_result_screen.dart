import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';

/// Màn hình đích sau callback thanh toán. Luôn tải lại booking để trạng thái hiển thị
/// phản ánh kết quả đã được backend xác nhận, thay vì chỉ tin query string.
class PaymentResultScreen extends ConsumerStatefulWidget {
  const PaymentResultScreen(
      {super.key,
      required this.bookingId,
      required this.result,
      this.intentId});

  final String? bookingId;
  final String result;
  final String? intentId;

  @override
  ConsumerState<PaymentResultScreen> createState() =>
      _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen>
    with WidgetsBindingObserver {
  var _isRefreshing = true;
  BookingModel? _booking;
  String? _intentStatus;
  Timer? _timer;
  int _attempts = 0;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_requesting || !mounted) return;
    _requesting = true;
    _timer?.cancel();
    setState(() => _isRefreshing = true);
    final repository = ref.read(bookingRepositoryProvider);
    try {
      if (widget.intentId?.isNotEmpty == true) {
        final intent = await repository.getPaymentIntent(widget.intentId!);
        if (!mounted) return;
        _intentStatus = intent.status;
      }
    } catch (_) {
      // Booking vẫn phải được đọc khi cổng thanh toán tạm thời không phản hồi.
    }
    try {
      if (widget.bookingId != null) {
        final booking = await repository.getBooking(widget.bookingId!);
        if (!mounted) return;
        _booking = booking;
      }
    } catch (_) {
      // Giữ trạng thái chưa xác minh; lỗi mạng không phải là thanh toán thất bại.
    } finally {
      _requesting = false;
    }
    if (!mounted) return;
    setState(() => _isRefreshing = false);
    if (_state == _PaymentResultState.syncing && ++_attempts < 5) {
      _timer = Timer(const Duration(seconds: 2), () => unawaited(_refresh()));
    } else if (_state == _PaymentResultState.success) {
      unawaited(ref.read(bookingStoreProvider.notifier).refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attempts = 0;
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  _PaymentResultState get _state {
    const paidStatuses = {
      'confirmed',
      'caregiver_accepted',
      'caregiver_en_route',
      'in_progress',
      'checkout_pending_review',
      'completed',
      'crisis'
    };
    if (paidStatuses.contains(_booking?.status)) {
      return _PaymentResultState.success;
    }
    if (const {'needs_manual_review', 'disputed'}.contains(_booking?.status)) {
      return _PaymentResultState.review;
    }
    if (const {'FAILED', 'EXPIRED', 'CANCELLED', 'SUPERSEDED'}
            .contains(_intentStatus) ||
        const {'cancelled', 'refunded', 'matching_failed'}
            .contains(_booking?.status)) {
      return _PaymentResultState.failure;
    }
    if (_intentStatus == 'SUCCEEDED') return _PaymentResultState.syncing;
    return _PaymentResultState.syncing;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kết quả thanh toán'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => context.go('/bookings'),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Đóng',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: _PaymentResultContent(
                state: state,
                refreshing: _isRefreshing,
                bookingId: widget.bookingId,
                onOpenBooking: widget.bookingId == null
                    ? null
                    : () => context.go('/bookings/${widget.bookingId}'),
                onOpenBookings: () => context.go('/bookings'),
                onRetry: _isRefreshing
                    ? null
                    : () {
                        _attempts = 0;
                        unawaited(_refresh());
                      },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PaymentResultState { success, syncing, failure, review }

class _PaymentResultContent extends StatelessWidget {
  const _PaymentResultContent({
    required this.state,
    required this.bookingId,
    required this.onOpenBooking,
    required this.onOpenBookings,
    required this.onRetry,
    required this.refreshing,
  });

  final _PaymentResultState state;
  final String? bookingId;
  final VoidCallback? onOpenBooking;
  final VoidCallback onOpenBookings;
  final VoidCallback? onRetry;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final details = switch (state) {
      _PaymentResultState.success => const _ResultDetails(
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
            _Highlight(Icons.verified_user_outlined,
                'CareSitter đã ghi nhận khoản thanh toán của bạn.'),
            _Highlight(Icons.person_search_outlined,
                'Theo dõi người chăm sóc và tiến độ ca trong lịch hẹn.'),
          ],
        ),
      _PaymentResultState.syncing => const _ResultDetails(
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
            _Highlight(Icons.schedule_outlined,
                'Nếu đã chuyển tiền, hãy chờ xác nhận và kiểm tra lại.'),
            _Highlight(Icons.notifications_none_rounded,
                'Bạn có thể mở lại lịch hẹn để xem trạng thái mới nhất.'),
          ],
        ),
      _PaymentResultState.failure => const _ResultDetails(
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
            _Highlight(Icons.lock_outline_rounded,
                'Kiểm tra lịch sử chuyển khoản tại ngân hàng của bạn.'),
            _Highlight(Icons.support_agent_outlined,
                'Nếu tiền đã bị trừ, hãy liên hệ hỗ trợ để được đối soát.'),
          ],
        ),
      _PaymentResultState.review => const _ResultDetails(
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
              _Highlight(Icons.receipt_long_outlined,
                  'Giữ lại biên lai chuyển khoản để hỗ trợ đối chiếu.')
            ]),
    };
    final isFailure = state == _PaymentResultState.failure;
    final isSyncing = state == _PaymentResultState.syncing;

    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                  color: details.iconBackground, shape: BoxShape.circle),
              child: Icon(details.icon, size: 48, color: details.iconColor),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: details.labelBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                details.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: details.labelColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            details.title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            details.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              children: [
                for (var index = 0;
                    index < details.highlights.length;
                    index++) ...[
                  _HighlightRow(highlight: details.highlights[index]),
                  if (index < details.highlights.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1),
                    ),
                ],
                if (bookingId != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mã lịch hẹn',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      Text(
                        '${bookingId!.substring(0, bookingId!.length.clamp(0, 8)).toUpperCase()}…',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (!isSyncing)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onOpenBooking,
                icon: Icon(isFailure
                    ? Icons.refresh_rounded
                    : Icons.calendar_month_outlined),
                label: const Text('Xem chi tiết lịch hẹn'),
              ),
            )
          else if (refreshing)
            const Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5)))
          else
            SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Kiểm tra lại thanh toán'))),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onOpenBookings,
            child: Text(isFailure
                ? 'Về danh sách lịch hẹn'
                : 'Quay lại danh sách lịch hẹn'),
          ),
        ],
      ),
    );
  }
}

class _ResultDetails {
  const _ResultDetails({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    required this.label,
    required this.labelColor,
    required this.labelBackground,
    required this.highlights,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final String label;
  final Color labelColor;
  final Color labelBackground;
  final List<_Highlight> highlights;
}

class _Highlight {
  const _Highlight(this.icon, this.text);

  final IconData icon;
  final String text;
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({required this.highlight});

  final _Highlight highlight;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(highlight.icon, color: AppColors.primaryDark, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              highlight.text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.45),
            ),
          ),
        ],
      );
}
