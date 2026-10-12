import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../data/repositories/booking_repository.dart';
import '../../domain/payment_outcome.dart';
import 'booking_controller.dart';
import 'payment_result_state.dart';

typedef PaymentResultArgs = ({String? bookingId, String? intentId});

final paymentResultControllerProvider = StateNotifierProvider.autoDispose
    .family<PaymentResultController, PaymentResultState, PaymentResultArgs>(
        (ref, args) {
  ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId));
  final repository = ref.watch(bookingRepositoryProvider);
  final controller = PaymentResultController(
    args: args,
    readBookingStatus: (id) async => (await repository.getBooking(id)).status,
    readIntentStatus: (id) async =>
        (await repository.getPaymentIntent(id)).status,
    onConfirmed: () => ref.read(bookingStoreProvider.notifier).refresh(),
  );
  Future.microtask(controller.refresh);
  return controller;
});

class PaymentResultController extends StateNotifier<PaymentResultState> {
  PaymentResultController({
    required this.args,
    required this.readBookingStatus,
    required this.readIntentStatus,
    required this.onConfirmed,
    this.pollInterval = const Duration(seconds: 2),
  }) : super(const PaymentResultState());

  final PaymentResultArgs args;
  final Future<String> Function(String) readBookingStatus;
  final Future<String> Function(String) readIntentStatus;
  final Future<void> Function() onConfirmed;
  final Duration pollInterval;
  Timer? _timer;
  int _generation = 0;
  int _attempts = 0;
  bool _requesting = false;
  bool _suspended = false;

  bool _current(int generation) => mounted && generation == _generation;

  Future<void> refresh() async {
    if (!mounted || _suspended || _requesting) return;
    _requesting = true;
    final generation = _generation;
    _timer?.cancel();
    var bookingStatus = state.bookingStatus;
    var intentStatus = state.intentStatus;
    state = PaymentResultState(
        bookingStatus: bookingStatus, intentStatus: intentStatus);
    try {
      if (args.intentId?.isNotEmpty == true) {
        intentStatus = await readIntentStatus(args.intentId!);
      }
    } catch (_) {
      // A failed read does not establish that payment failed.
    }
    if (!_current(generation)) return;
    try {
      if (args.bookingId?.isNotEmpty == true) {
        bookingStatus = await readBookingStatus(args.bookingId!);
      }
    } catch (_) {
      // Keep the last verified status while the backend is unavailable.
    }
    if (!_current(generation)) return;
    _requesting = false;
    state = PaymentResultState(
      refreshing: false,
      bookingStatus: bookingStatus,
      intentStatus: intentStatus,
    );
    if (state.outcome == PaymentOutcome.syncing && ++_attempts < 5) {
      _timer = Timer(pollInterval, () => unawaited(refresh()));
    } else if (state.outcome == PaymentOutcome.success) {
      unawaited(onConfirmed().catchError((_) {}));
    }
  }

  Future<void> retry() {
    _attempts = 0;
    return refresh();
  }

  void suspend() {
    _suspended = true;
    _generation++;
    _requesting = false;
    _timer?.cancel();
  }

  void resume() {
    _suspended = false;
    unawaited(retry());
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
