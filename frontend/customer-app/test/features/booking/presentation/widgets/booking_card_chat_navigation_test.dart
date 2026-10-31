import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/booking_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('booking card chat icon opens the booking conversation',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
                  body: ListView(children: [
                BookingCard(booking: _booking('caregiver_accepted')),
              ]))),
      GoRoute(
          path: AppRoutes.bookingChat(_bookingId),
          builder: (_, __) =>
              const Scaffold(body: Text('Booking chat opened'))),
      GoRoute(
          path: AppRoutes.bookingDetail(_bookingId),
          builder: (_, __) =>
              const Scaffold(body: Text('Booking detail opened'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Booking chat opened'), findsOneWidget);
  });

  testWidgets('booking awaiting caregiver does not offer chat', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: ListView(
              children: [BookingCard(booking: _booking('confirmed'))])),
    ));
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
  });
}

const _bookingId = '669b5213-5405-45f6-a2ba-ec70fb57a2fe';

BookingModel _booking(String status) => BookingModel(
      id: _bookingId,
      beneficiaryId: 'beneficiary',
      caregiverId: 'caregiver',
      addressId: 'address',
      serviceTypeId: 'service',
      scheduledStart: DateTime(2026, 10, 30, 8),
      scheduledEnd: DateTime(2026, 10, 30, 12),
      status: status,
      escrowAmount: 390000,
      platformFeeAmount: 58500,
      createdAt: DateTime(2026, 10, 29),
      updatedAt: DateTime(2026, 10, 30),
      caregiverName: 'Nguyễn A',
      beneficiaryName: 'Trần B',
      serviceName: 'Chăm sóc',
    );
