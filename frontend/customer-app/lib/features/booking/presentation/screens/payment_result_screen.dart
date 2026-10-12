import 'package:caresitter_customer/features/booking/presentation/widgets/payment_result_payment_result_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../controllers/payment_result_controller.dart';

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
  PaymentResultArgs get _args =>
      (bookingId: widget.bookingId, intentId: widget.intentId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller =
        ref.read(paymentResultControllerProvider(_args).notifier);
    if (state == AppLifecycleState.resumed) {
      controller.resume();
    } else {
      controller.suspend();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(paymentResultControllerProvider(_args));
    final state = flow.outcome;

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
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
              child: PaymentResultPaymentResultContent(
                state: state,
                refreshing: flow.refreshing,
                bookingId: widget.bookingId,
                onOpenBooking: widget.bookingId == null
                    ? null
                    : () => context.go('/bookings/${widget.bookingId}'),
                onOpenBookings: () => context.go('/bookings'),
                onRetry: flow.refreshing
                    ? null
                    : () => ref
                        .read(paymentResultControllerProvider(_args).notifier)
                        .retry(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
