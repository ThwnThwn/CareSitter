import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import '../../data/models/payment_intent_model.dart';
import '../../data/models/payment_provider_model.dart';
import '../../domain/payment_error_codes.dart';
import '../../domain/payment_url_rules.dart';
import 'booking_controller.dart';
import 'payment_checkout_state.dart';
import 'payment_checkout_result.dart';
export 'payment_checkout_state.dart';
export 'payment_checkout_result.dart';

final paymentProvidersProvider =
    FutureProvider.autoDispose<List<PaymentProviderModel>>((ref) {
  ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId));
  return ref.read(bookingStoreProvider.notifier).getPaymentProviders();
});

final paymentCheckoutControllerProvider = StateNotifierProvider.autoDispose
    .family<PaymentCheckoutController, PaymentCheckoutState, String>((ref, id) {
  ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  final store = ref.read(bookingStoreProvider.notifier);
  return PaymentCheckoutController(
      (provider) => store.createPaymentIntent(id, provider));
});

class PaymentCheckoutController extends StateNotifier<PaymentCheckoutState> {
  PaymentCheckoutController(this.createIntent)
      : super(const PaymentCheckoutState());
  final Future<PaymentIntentModel> Function(String) createIntent;
  void select(String provider, {required bool enabled}) {
    if (!state.busy && enabled) {
      state = PaymentCheckoutState(selected: provider);
    }
  }

  Future<PaymentCheckoutResult> prepare() async {
    final selected = state.selected;
    if (!mounted || state.busy || selected == null) {
      return const PaymentCheckoutIgnored();
    }
    state = PaymentCheckoutState(selected: selected, busy: true);
    try {
      final intent = await createIntent(selected);
      if (!mounted) return const PaymentCheckoutIgnored();
      if (intent.status == 'SUCCEEDED') {
        return PaymentCheckoutReady(intent, null);
      }
      final uri = validPaymentUrl(intent.paymentUrl, selected);
      if (uri == null) {
        launchFailed();
        return const PaymentCheckoutIgnored();
      }
      return PaymentCheckoutReady(intent, uri);
    } on AppApiException catch (error) {
      if (!mounted) return const PaymentCheckoutIgnored();
      if (error.code == PaymentErrorCodes.alreadySucceeded) {
        return const PaymentCheckoutReady(
            PaymentIntentModel(id: '', status: 'SUCCEEDED', paymentUrl: ''),
            null);
      }
      state = PaymentCheckoutState(selected: selected, error: error.message);
      return const PaymentCheckoutIgnored();
    } catch (_) {
      if (mounted) launchFailed();
      return const PaymentCheckoutIgnored();
    }
  }

  void launchFailed() {
    if (mounted) {
      state = PaymentCheckoutState(
          selected: state.selected,
          error: 'Chưa mở được thanh toán. Vui lòng thử lại.');
    }
  }

  void finishLaunch() {
    if (mounted) state = PaymentCheckoutState(selected: state.selected);
  }
}
