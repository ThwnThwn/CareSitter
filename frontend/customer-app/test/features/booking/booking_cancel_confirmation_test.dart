import 'dart:async';

import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_toast.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await font.load();
  });
  late _CancelRepository repository;

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bookingStoreProvider.overrideWith(_BookingStore.new),
        bookingRepositoryProvider.overrideWith((ref) {
          return repository = _CancelRepository(DioClient(ref));
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const BookingDetailScreen(id: 'booking-1'),
      ),
    ));
    await tester.pumpAndSettle();
    // Khởi tạo repository mà không gửi request.
    ProviderScope.containerOf(
      tester.element(find.byType(BookingDetailScreen)),
    ).read(bookingRepositoryProvider);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> tapCancel(WidgetTester tester) async {
    final button = find.widgetWithText(OutlinedButton, 'Hủy lịch hẹn');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('keeping a booking never sends a cancellation request',
      (tester) async {
    await open(tester);
    await tapCancel(tester);
    expect(find.text('Hủy lịch hẹn?'), findsOneWidget);
    expect(repository.calls, 0);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Đóng'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(find.text('Chờ kiểm tra'), findsWidgets);
    expect(find.text('Đã hủy lịch hẹn'), findsNothing);
  });

  testWidgets(
      'confirmed cancellation waits for the server and prevents repeats',
      (tester) async {
    await open(tester);
    await tapCancel(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Hủy lịch hẹn'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.calls, 1);
    expect(find.text('Đã hủy lịch hẹn'), findsNothing);
    final pendingButton = find.widgetWithText(OutlinedButton, 'Đang hủy...');
    expect(tester.widget<OutlinedButton>(pendingButton).onPressed, isNull);
    expect(
        tester
            .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.more_vert))
            .onPressed,
        isNull);
    await tester.tap(pendingButton);
    await tester.pump();
    expect(repository.calls, 1);

    final cancelledAt = DateTime.utc(2026, 10, 8, 9);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BookingDetailScreen)),
    );
    repository.result
        .complete(container.read(bookingStoreProvider).single.copyWith(
              status: 'cancelled',
              cancelledAt: cancelledAt,
              updatedAt: cancelledAt,
              syncVersion: 1,
            ));
    await tester.pumpAndSettle();
    expect(find.text('Đã hủy lịch hẹn'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Hủy lịch hẹn'), findsNothing);
    expect(
        container.read(bookingStoreProvider).single.cancelledAt, cancelledAt);
    expect(tester.takeException(), isNull);
    AppToast.dismiss(tester.element(find.byType(BookingDetailScreen)));
    await tester.pump();
  });

  testWidgets('a failed cancellation preserves the booking and shows an error',
      (tester) async {
    await open(tester);
    await tapCancel(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Hủy lịch hẹn'));
    await tester.pump();
    repository.result.completeError(const AppApiException(
      message: 'Lịch hẹn đang được xử lý. Vui lòng thử lại.',
      statusCode: 409,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Lịch hẹn đang được xử lý. Vui lòng thử lại.'),
        findsOneWidget);
    expect(find.text('Đã hủy lịch hẹn'), findsNothing);
    final button = find.widgetWithText(OutlinedButton, 'Hủy lịch hẹn');
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    expect(find.text('Chờ kiểm tra'), findsWidgets);
    expect(tester.takeException(), isNull);
    AppToast.dismiss(tester.element(find.byType(BookingDetailScreen)));
    await tester.pump();
  });

  testWidgets('the overflow menu uses the same confirmation before cancelling',
      (tester) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Hủy lịch hẹn'));
    await tester.pumpAndSettle();
    expect(find.text('Hủy lịch hẹn?'), findsOneWidget);
    expect(repository.calls, 0);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(tester.takeException(), isNull);
  });
}

class _CancelRepository extends BookingRepository {
  _CancelRepository(super.dio);

  int calls = 0;
  final result = Completer<BookingModel>();

  @override
  Future<BookingModel> cancelBooking(String bookingId, {String? reason}) async {
    calls++;
    return result.future;
  }
}

class _BookingStore extends BookingStore {
  @override
  List<BookingModel> build() => [
        BookingModel(
          id: 'booking-1',
          beneficiaryId: 'beneficiary-1',
          addressId: 'address-1',
          serviceTypeId: 'service-1',
          scheduledStart: DateTime(2026, 11, 1, 8),
          scheduledEnd: DateTime(2026, 11, 1, 12),
          status: 'needs_manual_review',
          escrowAmount: 300000,
          platformFeeAmount: 0,
          createdAt: DateTime(2026, 10, 8),
          updatedAt: DateTime(2026, 10, 8),
          beneficiaryName: 'Người thân',
          addressText: '123 Nguyễn Huệ',
          serviceName: 'Gói hỗ trợ sinh hoạt',
        ),
      ];
}
