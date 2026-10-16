import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/payment_checkout_sheet.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/payment_result_screen.dart';

BookingModel booking([String status = 'pending_payment']) =>
    BookingModel.fromJson({
      'id': 'booking-123',
      'status': status,
      'escrowAmount': 100000,
      'customerPayableAmount': 75000,
      'scheduledStart': '2026-10-09T07:00:00Z',
      'scheduledEnd': '2026-10-09T09:00:00Z',
    });

class FakePayments extends BookingRepository {
  FakePayments(super.client);
  bool enabled = true;
  bool failProvidersOnce = false;
  int providerLoads = 0;
  int creates = 0;
  final keys = <String?>[];
  String? usedProvider;
  Completer<PaymentIntentModel>? pending;
  BookingModel current = booking();
  String intentStatus = 'PENDING';
  @override
  Future<List<PaymentProviderModel>> getPaymentProviders() async {
    providerLoads++;
    if (failProvidersOnce) {
      failProvidersOnce = false;
      throw StateError('Temporary provider failure');
    }
    return [
      PaymentProviderModel(
          code: 'PAYOS',
          name: 'payOS',
          description: 'Chuyển khoản VietQR',
          enabled: enabled),
      const PaymentProviderModel(
          code: 'VNPAY',
          name: 'VNPAY',
          description: 'Ngân hàng, ví hoặc thẻ',
          enabled: true),
    ];
  }

  @override
  Future<PaymentIntentModel> createPaymentIntent(
      String bookingId, String provider,
      {String? idempotencyKey}) async {
    creates++;
    usedProvider = provider;
    keys.add(idempotencyKey);
    if (pending != null) return pending!.future;
    return const PaymentIntentModel(
        id: 'intent-123',
        status: 'PENDING',
        paymentUrl: 'https://pay.payos.vn/web/link123');
  }

  @override
  Future<PaymentIntentModel> getPaymentIntent(String id) async =>
      PaymentIntentModel(id: id, status: intentStatus, paymentUrl: '');
  @override
  Future<BookingModel> getBooking(String id) async => current;
}

class QuietBookingStore extends BookingStore {
  @override
  List<BookingModel> build() => [];
  @override
  Future<void> refresh() async {}
}

void main() {
  test('payment retries reuse a key and another provider gets a different key',
      () async {
    final repository = FakePayments(_UnusedPaymentClient());
    final container = ProviderContainer(overrides: [
      bookingRepositoryProvider.overrideWithValue(repository),
      bookingStoreProvider.overrideWith(QuietBookingStore.new)
    ]);
    addTearDown(container.dispose);
    final controller = container.read(bookingStoreProvider.notifier);
    await controller.createPaymentIntent('booking', 'PAYOS');
    await controller.createPaymentIntent('booking', 'PAYOS');
    await controller.createPaymentIntent('booking', 'VNPAY');
    expect(repository.keys.first, isNotEmpty);
    expect(repository.keys[1], repository.keys.first);
    expect(repository.keys[2], isNot(repository.keys.first));
  });
  late FakePayments repository;
  Future<void> pump(WidgetTester tester, Widget child,
      {bool enabled = true,
      Size size = const Size(390, 844),
      double scale = 1}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWith((ref) =>
              repository = FakePayments(DioClient(ref))..enabled = enabled),
          bookingStoreProvider.overrideWith(QuietBookingStore.new),
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
                data: MediaQueryData(
                    size: size, textScaler: TextScaler.linear(scale)),
                child: Scaffold(body: child)))));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('payOS is visible but cannot be selected when disabled',
      (tester) async {
    await pump(tester, PaymentCheckoutSheet(booking: booking()),
        enabled: false);
    expect(find.text('payOS'), findsOneWidget);
    expect(find.text('Hiện chưa khả dụng'), findsOneWidget);
    await tester.tap(find.text('payOS'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    expect(repository.creates, 0);
  });

  testWidgets('provider loading failure offers a working retry',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWith((ref) => repository =
              FakePayments(DioClient(ref))..failProvidersOnce = true),
          bookingStoreProvider.overrideWith(QuietBookingStore.new),
        ],
        child: MaterialApp(
            home: Scaffold(body: PaymentCheckoutSheet(booking: booking())))));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được phương thức thanh toán.'), findsOneWidget);
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(find.text('payOS'), findsOneWidget);
    expect(repository.providerLoads, 2);
  });

  testWidgets(
      'loading prevents repeated create requests and keeps server payable amount',
      (tester) async {
    await pump(
        tester,
        PaymentCheckoutSheet(
            booking: booking(), openCheckout: (_) async => true));
    expect(find.text('75.000 ₫'), findsOneWidget);
    repository.pending = Completer<PaymentIntentModel>();
    await tester.tap(find.text('payOS'));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục thanh toán'));
    await tester.pump();
    expect(repository.usedProvider, 'PAYOS');
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(repository.creates, 1);
    repository.pending!.completeError(StateError('Simulated network error'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa mở được thanh toán. Vui lòng thử lại.'),
        findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
  });

  testWidgets('forged success callback cannot show successful payment',
      (tester) async {
    await pump(
        tester,
        const PaymentResultScreen(
            bookingId: 'booking-123',
            intentId: 'intent-123',
            result: 'success'));
    expect(find.text('Thanh toán thành công'), findsNothing);
    expect(find.text('Đang xác nhận thanh toán'), findsOneWidget);
    repository.intentStatus = 'SUCCEEDED';
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Thanh toán thành công'), findsNothing);
    repository.current = booking('confirmed');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Thanh toán thành công'), findsOneWidget);
  });

  testWidgets('manual review is shown without asking for another payment',
      (tester) async {
    await pump(tester,
        const PaymentResultScreen(bookingId: 'booking-123', result: 'success'));
    repository.current = booking('needs_manual_review');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Giao dịch cần đối soát'), findsOneWidget);
    expect(find.text('Thanh toán thành công'), findsNothing);
  });

  testWidgets('checkout fits narrow screens with large text', (tester) async {
    await pump(tester, PaymentCheckoutSheet(booking: booking()),
        size: const Size(320, 640), scale: 1.5);
    expect(tester.takeException(), isNull);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục thanh toán'), findsOneWidget);
  });
}

class _UnusedPaymentClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
