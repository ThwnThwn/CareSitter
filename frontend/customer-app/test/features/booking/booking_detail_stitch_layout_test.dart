import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('booking detail keeps the Stitch hierarchy at 320 px',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_PreviewBookingStore.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: const BookingDetailScreen(id: 'booking-preview'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('booking-detail-hero')), findsOneWidget);
    expect(find.text('Hỗ trợ thiết yếu'), findsWidgets);
    expect(find.text('Hỗ trợ phi y tế tại nhà'), findsOneWidget);
    expect(find.text('Caregiver đồng hành'), findsOneWidget);
    expect(find.text('Thông tin lịch hẹn'), findsOneWidget);
    expect(find.text('Thanh toán'), findsOneWidget);
    final layoutError = tester.takeException();
    expect(
      layoutError,
      isNull,
      reason: layoutError is FlutterError ? layoutError.toStringDeep() : null,
    );
  });
}

class _PreviewBookingStore extends BookingStore {
  @override
  List<BookingModel> build() => [
        BookingModel(
          id: 'booking-preview',
          beneficiaryId: 'beneficiary-preview',
          caregiverId: 'caregiver-preview',
          addressId: 'address-preview',
          serviceTypeId: 'service-preview',
          scheduledStart: DateTime(2030, 11, 1, 8),
          scheduledEnd: DateTime(2030, 11, 1, 12),
          status: 'confirmed',
          escrowAmount: 360000,
          platformFeeAmount: 54000,
          createdAt: DateTime(2026, 10, 23),
          updatedAt: DateTime(2026, 10, 23),
          beneficiaryName: 'Bà Nguyễn Thị Minh Anh',
          caregiverName: 'Trần Thị Thu',
          addressText: '123 Nguyễn Huệ, phường Sài Gòn, TP.HCM',
          serviceName: 'Hỗ trợ thiết yếu',
        ),
      ];
}
