import 'package:caresitter_customer/core/router/app_routes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('caregiver contact opens chat for the selected booking',
      (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.bookingDetail('booking-preview'),
      routes: [
        GoRoute(
          path: '/bookings/:id',
          builder: (_, state) =>
              BookingDetailScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/bookings/:id/chat',
          builder: (_, state) => Scaffold(
            body: Text('Chat ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [bookingStoreProvider.overrideWith(_BookingStore.new)],
      child:
          MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ));
    await tester.pumpAndSettle();

    final chatButton = find.text('Nhắn tin');
    await tester.ensureVisible(chatButton);
    await tester.tap(chatButton);
    await tester.pumpAndSettle();

    expect(find.text('Chat booking-preview'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(BookingDetailScreen), findsOneWidget);
  });
}

class _BookingStore extends BookingStore {
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
          createdAt: DateTime(2026, 10, 28),
          updatedAt: DateTime(2026, 10, 28),
          beneficiaryName: 'Người nhận thử nghiệm',
          caregiverName: 'Caregiver thử nghiệm',
          addressText: 'Địa chỉ thử nghiệm',
          serviceName: 'Hỗ trợ thiết yếu',
        ),
      ];
}
