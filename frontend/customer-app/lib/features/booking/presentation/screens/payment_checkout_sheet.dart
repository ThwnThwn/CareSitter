import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';

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
  late Future<List<PaymentProviderModel>> _providers;
  String? _selected;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _providers = ref.read(bookingRepositoryProvider).getPaymentProviders();
  }

  Future<void> _pay() async {
    if (_submitting || _selected == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final intent = await ref
          .read(bookingRepositoryProvider)
          .createPaymentIntent(widget.booking.id, _selected!);
      if (!mounted) return;
      if (intent.status != 'SUCCEEDED') {
        final uri = Uri.tryParse(intent.paymentUrl);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            (_selected == 'PAYOS' && uri.host != 'pay.payos.vn')) {
          throw StateError('URL thanh toán không hợp lệ.');
        }
        final opened = await (widget.openCheckout?.call(uri) ??
            launchUrl(uri,
                mode: kIsWeb
                    ? LaunchMode.platformDefault
                    : LaunchMode.externalApplication,
                webOnlyWindowName: kIsWeb ? '_self' : null));
        if (!opened) throw StateError('Không mở được trang thanh toán.');
      }
      if (mounted) Navigator.pop(context, intent);
    } catch (error) {
      if (!mounted) return;
      final apiError = error is DioException && error.error is AppApiException
          ? error.error as AppApiException
          : error is AppApiException
              ? error
              : null;
      if (apiError?.code == 'PAYMENT_ALREADY_SUCCEEDED') {
        Navigator.pop(
            context,
            const PaymentIntentModel(
                id: '', status: 'SUCCEEDED', paymentUrl: ''));
        return;
      }
      setState(() => _error =
          apiError?.message ?? 'Chưa mở được thanh toán. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_submitting,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('Chọn cách thanh toán',
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                        onPressed:
                            _submitting ? null : () => Navigator.pop(context),
                        tooltip: 'Đóng',
                        icon: const Icon(Icons.close_rounded)),
                  ]),
                  const SizedBox(height: 12),
                  Text('${_formatAmount(widget.booking.payableAmount)} ₫',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                      'Thanh toán trước để xác nhận lịch hẹn. Hãy kiểm tra số tiền và người nhận trên trang thanh toán.',
                      style: TextStyle(
                          color: AppColors.textSecondary, height: 1.5)),
                  const SizedBox(height: 24),
                  FutureBuilder<List<PaymentProviderModel>>(
                    future: _providers,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()));
                      }
                      if (snapshot.hasError) {
                        return Column(children: [
                          const Text('Chưa tải được phương thức thanh toán.'),
                          TextButton(
                              onPressed: () => setState(() {
                                    _providers = ref
                                        .read(bookingRepositoryProvider)
                                        .getPaymentProviders();
                                  }),
                              child: const Text('Tải lại')),
                        ]);
                      }
                      final providers = snapshot.data ?? [];
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final provider in providers)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Semantics(
                                  selected: _selected == provider.code,
                                  child: Material(
                                    color: _selected == provider.code
                                        ? AppColors.successLight
                                        : AppColors.surface,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                            color: _selected == provider.code
                                                ? AppColors.primary
                                                : AppColors.border)),
                                    clipBehavior: Clip.antiAlias,
                                    child: ListTile(
                                      enabled: provider.enabled && !_submitting,
                                      onTap: provider.enabled && !_submitting
                                          ? () => setState(
                                              () => _selected = provider.code)
                                          : null,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                      leading: Icon(
                                          provider.code == 'PAYOS'
                                              ? Icons.qr_code_rounded
                                              : Icons.account_balance_outlined,
                                          color: provider.enabled
                                              ? AppColors.primary
                                              : AppColors.textSecondary),
                                      title: Text(provider.name,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: provider.enabled
                                                  ? AppColors.textPrimary
                                                  : AppColors.textSecondary)),
                                      subtitle: Text(
                                          provider.enabled
                                              ? provider.description
                                              : 'Hiện chưa khả dụng',
                                          style: const TextStyle(
                                              color: AppColors.textSecondary)),
                                      trailing: Icon(
                                          _selected == provider.code
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: provider.enabled
                                              ? AppColors.primary
                                              : AppColors.textSecondary),
                                    ),
                                  ),
                                ),
                              ),
                            if (!providers.any((p) => p.enabled))
                              const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                      'Thanh toán trực tuyến hiện chưa mở. Vui lòng liên hệ hỗ trợ.',
                                      style: TextStyle(
                                          color: AppColors.textSecondary))),
                          ]);
                    },
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(_error!,
                              style: const TextStyle(color: AppColors.error))),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            _selected == null || _submitting ? null : _pay,
                        child: _submitting
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

  String _formatAmount(int amount) => amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.');
}
