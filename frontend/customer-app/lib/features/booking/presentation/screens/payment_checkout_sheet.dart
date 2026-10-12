import '../controllers/payment_checkout_controller.dart';
import '../widgets/payment_provider_choices.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class PaymentCheckoutSheet extends ConsumerStatefulWidget {
  const PaymentCheckoutSheet(
      {super.key, required this.booking, this.openCheckout});
  final BookingModel booking;
  final Future<bool> Function(Uri)? openCheckout;

  @override
  ConsumerState<PaymentCheckoutSheet> createState() =>
      _PaymentCheckoutSheetState();
}

class _PaymentCheckoutSheetState extends ConsumerState<PaymentCheckoutSheet> {
  Future<void> _pay() async {
    final controller =
        ref.read(paymentCheckoutControllerProvider(widget.booking.id).notifier);
    final result = await controller.prepare();
    if (!mounted || !controller.mounted || result is! PaymentCheckoutReady) {
      return;
    }
    try {
      if (result.uri != null) {
        final opened = await (widget.openCheckout?.call(result.uri!) ??
            launchUrl(result.uri!,
                mode: kIsWeb
                    ? LaunchMode.platformDefault
                    : LaunchMode.externalApplication,
                webOnlyWindowName: kIsWeb ? '_self' : null));
        if (!mounted || !controller.mounted) return;
        if (!opened) {
          controller.launchFailed();
          return;
        }
      }
      controller.finishLaunch();
      if (mounted) Navigator.pop(context, result.intent);
    } catch (_) {
      if (mounted && controller.mounted) controller.launchFailed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow =
        ref.watch(paymentCheckoutControllerProvider(widget.booking.id));
    final providers = ref.watch(paymentProvidersProvider);
    return PopScope(
      canPop: !flow.busy,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text('Chọn cách thanh toán',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  onPressed: flow.busy ? null : () => Navigator.pop(context),
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: AppSpacing.compact),
            Text('${_formatAmount(widget.booking.payableAmount)} ₫',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
                'Thanh toán trước để xác nhận lịch hẹn. Hãy kiểm tra số tiền và người nhận trên trang thanh toán.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: AppSpacing.lg),
            PaymentProviderChoices(
                providers: providers,
                selected: flow.selected,
                busy: flow.busy,
                onSelected: (provider) => ref
                    .read(paymentCheckoutControllerProvider(widget.booking.id)
                        .notifier)
                    .select(provider.code, enabled: provider.enabled)),
            if (flow.error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.compact),
                child: Semantics(
                    liveRegion: true,
                    child: Text(flow.error!,
                        style: const TextStyle(color: AppColors.error))),
              ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: flow.selected == null || flow.busy ? null : _pay,
                  child: flow.busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Tiếp tục thanh toán'),
                )),
          ]),
        ),
      ),
    );
  }

  String _formatAmount(int amount) => formatVnd(amount, suffix: '');
}
