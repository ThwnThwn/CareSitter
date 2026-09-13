import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/booking_store.dart';

/// Màn hình đích sau callback VNPay. Trạng thái booking luôn được tải lại từ API.
class PaymentResultScreen extends ConsumerStatefulWidget {
  const PaymentResultScreen({super.key, required this.bookingId, required this.result});

  final String? bookingId;
  final String result;

  @override
  ConsumerState<PaymentResultScreen> createState() => _PaymentResultScreenState();
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
        : ref.watch(bookingStoreProvider).where((item) => item.id == widget.bookingId).firstOrNull;
    final isConfirmed = booking?.status == 'confirmed';
    final isSuccess = widget.result == 'success' && (isConfirmed || booking == null);
    final title = isSuccess ? 'Thanh toán thành công' : 'Thanh toán chưa hoàn tất';
    final message = isSuccess
        ? isConfirmed
            ? 'Lịch hẹn đã được xác nhận. Chúng tôi đang tìm người chăm sóc phù hợp.'
            : 'Chúng tôi đã nhận kết quả thanh toán. Đang đồng bộ lịch hẹn của bạn.'
        : 'Giao dịch chưa được xác nhận. Bạn có thể xem lại lịch hẹn hoặc thử thanh toán lại.';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kết quả thanh toán'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: isSuccess ? AppColors.successLight : AppColors.errorLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSuccess ? Icons.check_rounded : Icons.info_outline_rounded,
                      size: 46,
                      color: isSuccess ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 32),
                  if (_isRefreshing) const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.bookingId == null ? null : () => context.go('/bookings/${widget.bookingId}'),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Xem chi tiết lịch hẹn'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go('/bookings'),
                    child: const Text('Về danh sách lịch hẹn'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
