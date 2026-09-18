import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

/// Màn hình đích sau callback VNPay. Luôn tải lại booking để trạng thái hiển thị
/// phản ánh kết quả đã được backend xác nhận, thay vì chỉ tin query string.
class PaymentResultScreen extends ConsumerStatefulWidget {
  const PaymentResultScreen(
      {super.key, required this.bookingId, required this.result});

  final String? bookingId;
  final String result;

  @override
  ConsumerState<PaymentResultScreen> createState() =>
      _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen> {
  var _isRefreshing = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await ref.read(bookingStoreProvider.notifier).refresh();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.bookingId == null
        ? null
        : ref
            .watch(bookingStoreProvider)
            .where((item) => item.id == widget.bookingId)
            .firstOrNull;
    final confirmed = booking?.status == 'confirmed';
    final failed = widget.result != 'success';
    final syncing = !failed && _isRefreshing && !confirmed;
    final succeeded = !failed && !syncing;
    final state = succeeded
        ? _PaymentResultState.success
        : syncing
            ? _PaymentResultState.syncing
            : _PaymentResultState.failure;

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
                bookingId: widget.bookingId,
                onOpenBooking: widget.bookingId == null
                    ? null
                    : () => context.go('/bookings/${widget.bookingId}'),
                onOpenBookings: () => context.go('/bookings'),
                onRetry: widget.bookingId == null
                    ? null
                    : () => context.go('/bookings/${widget.bookingId}'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PaymentResultState { success, syncing, failure }

class _PaymentResultContent extends StatelessWidget {
  const _PaymentResultContent({
    required this.state,
    required this.bookingId,
    required this.onOpenBooking,
    required this.onOpenBookings,
    required this.onRetry,
  });

  final _PaymentResultState state;
  final String? bookingId;
  final VoidCallback? onOpenBooking;
  final VoidCallback onOpenBookings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final details = switch (state) {
      _PaymentResultState.success => const _ResultDetails(
          icon: Icons.check_rounded,
          iconColor: AppColors.success,
          iconBackground: AppColors.successLight,
          title: 'Thanh toán thành công',
          message:
              'Lịch hẹn của bạn đã được xác nhận. Chúng tôi đang tìm người chăm sóc phù hợp.',
          label: 'ĐÃ XÁC NHẬN',
          labelColor: AppColors.success,
          labelBackground: AppColors.successLight,
          highlights: [
            _Highlight(Icons.verified_user_outlined,
                'Khoản thanh toán đã được giữ ký quỹ an toàn.'),
            _Highlight(Icons.person_search_outlined,
                'Bạn sẽ nhận thông báo ngay khi có người nhận ca.'),
          ],
        ),
      _PaymentResultState.syncing => const _ResultDetails(
          icon: Icons.sync_rounded,
          iconColor: AppColors.info,
          iconBackground: AppColors.infoLight,
          title: 'Đang xác nhận thanh toán',
          message:
              'Chúng tôi đã nhận kết quả từ VNPay và đang cập nhật lịch hẹn của bạn.',
          label: 'ĐANG ĐỒNG BỘ',
          labelColor: AppColors.info,
          labelBackground: AppColors.infoLight,
          highlights: [
            _Highlight(Icons.schedule_outlined,
                'Quá trình này thường chỉ mất vài giây.'),
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
              'Giao dịch chưa được xác nhận. Bạn chưa bị mất lịch hẹn và có thể thử lại khi sẵn sàng.',
          label: 'CẦN THANH TOÁN LẠI',
          labelColor: AppColors.error,
          labelBackground: AppColors.errorLight,
          highlights: [
            _Highlight(Icons.lock_outline_rounded,
                'Không có khoản nào được xác nhận từ giao dịch này.'),
            _Highlight(Icons.support_agent_outlined,
                'Nếu tiền đã bị trừ, hãy liên hệ hỗ trợ để được đối soát.'),
          ],
        ),
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
                    color: Color(0x120B3D26),
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
                        '${bookingId!.substring(0, 8).toUpperCase()}…',
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
                onPressed: isFailure ? onRetry : onOpenBooking,
                icon: Icon(isFailure
                    ? Icons.refresh_rounded
                    : Icons.calendar_month_outlined),
                label: Text(
                    isFailure ? 'Thử thanh toán lại' : 'Xem chi tiết lịch hẹn'),
              ),
            )
          else
            const Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5))),
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
