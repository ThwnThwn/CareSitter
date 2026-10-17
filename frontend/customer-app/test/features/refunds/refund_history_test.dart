import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caresitter_customer/features/refunds/data/models/refund_record.dart';
import 'package:caresitter_customer/features/refunds/presentation/widgets/refund_card.dart';

void main() {
  test('refund record parses customer-safe payload', () {
    final record = RefundRecord.fromJson({
      'id': 'refund-1',
      'bookingId': 'booking-1',
      'provider': 'vnpay',
      'amount': 125000,
      'currency': 'VND',
      'reason': 'CUSTOMER_CANCELLATION',
      'status': 'manual_required',
      'requestedAt': '2026-10-17T08:00:00Z',
    });

    expect(record.provider, 'VNPAY');
    expect(record.status, 'MANUAL_REQUIRED');
    expect(record.amount, 125000);
    expect(record.needsSupport, isTrue);
  });

  for (final status in const {
    'PENDING': 'Đang xử lý',
    'MANUAL_REQUIRED': 'Cần xử lý thủ công',
    'SUCCEEDED': 'Đã hoàn',
    'FAILED': 'Thất bại',
  }.entries) {
    testWidgets('refund card presents ${status.key}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var retries = 0;
      var supportRequests = 0;
      final record = RefundRecord(
        id: 'refund-1',
        bookingId: '12345678-1234-1234-1234-123456789012',
        provider: 'VNPAY',
        amount: 125000,
        currency: 'VND',
        reason: 'CUSTOMER_CANCELLATION',
        status: status.key,
        requestedAt: DateTime(2026, 10, 17, 15),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RefundCard(
              refund: record,
              onRetry: () => retries++,
              onSupport: () => supportRequests++,
            ),
          ),
        ),
      ));

      expect(find.text(status.value), findsOneWidget);
      expect(find.text('125.000đ'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      expect(retries, 1);

      if (record.needsSupport) {
        expect(find.text('Liên hệ hỗ trợ'), findsOneWidget);
        await tester.tap(find.text('Liên hệ hỗ trợ'));
        expect(supportRequests, 1);
      } else {
        expect(find.text('Liên hệ hỗ trợ'), findsNothing);
      }
    });
  }
}
