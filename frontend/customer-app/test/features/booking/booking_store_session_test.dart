import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/realtime/care_signalr_service.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

void main() {
  test(
      'real booking store resets cache and payment keys when the account changes',
      () async {
    final repository = _Repository();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      bookingRepositoryProvider.overrideWithValue(repository),
      careSignalRProvider.overrideWithValue(_Hub()),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    var store = container.read(bookingStoreProvider.notifier);
    await _flush();
    await store.createPaymentIntent('booking', 'PAYOS');
    await store.createPaymentIntent('booking', 'PAYOS');
    expect(repository.keys[0], repository.keys[1]);
    (container.read(authStateProvider.notifier) as _Auth).switchTo('second');
    expect(container.read(bookingStoreProvider), isEmpty);
    store = container.read(bookingStoreProvider.notifier);
    await _flush();
    await store.createPaymentIntent('booking', 'PAYOS');
    expect(repository.keys[2], isNot(repository.keys[0]));
    repository.loads.first.complete(_list('old-account'));
    await _flush();
    expect(container.read(bookingStoreProvider), isEmpty);
    repository.loads.last.complete(_list('second-account'));
    await _flush();
    expect(container.read(bookingStoreProvider).single.id, 'second-account');
  });
}

Future<void> _flush() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

BookingListResponse _list(String id) => BookingListResponse(items: [
      BookingModel.fromJson({'id': id})
    ], total: 1, page: 1, pageSize: 50);

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'first', isAuthenticated: true);
  void switchTo(String id) =>
      state = AsyncData(AuthState(userId: id, isAuthenticated: true));
}

class _Hub implements CareSignalRService {
  @override
  bool get isConnected => false;
  @override
  Future<void> connect() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Repository implements BookingRepository {
  final loads = <Completer<BookingListResponse>>[];
  final keys = <String?>[];
  @override
  Future<BookingListResponse> getBookings(
      {String? status, int page = 1, int pageSize = 20}) {
    final pending = Completer<BookingListResponse>();
    loads.add(pending);
    return pending.future;
  }

  @override
  Future<PaymentIntentModel> createPaymentIntent(String id, String provider,
      {String? idempotencyKey}) async {
    keys.add(idempotencyKey);
    return const PaymentIntentModel(
        id: 'payment', status: 'PENDING', paymentUrl: '');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
