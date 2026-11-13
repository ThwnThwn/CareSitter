import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/domain/payment_outcome.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/payment_result_payment_result_content.dart';

void main() {
  for (final status in ['matching_failed', 'refunded', 'cancelled']) {
    testWidgets('$status shows correct result and opens booking details',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaymentResultPaymentResultContent(
              state: paymentOutcome(
                  bookingStatus: status, intentStatus: 'SUCCEEDED'),
              bookingId: 'booking',
              refreshing: false,
              onOpenBooking: () => opened++,
              onOpenBookings: () {},
              onRetry: () {},
            ),
          ),
        ),
      ));
      final title = switch (status) {
        'matching_failed' => 'Đã thanh toán, chưa tìm được người chăm sóc',
        'refunded' => 'Khoản thanh toán đã được hoàn tiền',
        _ => 'Giao dịch cần đối soát',
      };
      expect(find.text(title), findsOneWidget);
      expect(find.text('Thanh toán chưa hoàn tất'), findsNothing);
      expect(find.text('CẦN THANH TOÁN LẠI'), findsNothing);
      final details = find.text('Xem chi tiết lịch hẹn');
      await tester.ensureVisible(details);
      await tester.tap(details);
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
