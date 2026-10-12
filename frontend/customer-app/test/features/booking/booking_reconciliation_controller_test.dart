import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_draft.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_reconciliation_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_submit_result.dart';

void main() {
  test('a single match in an exhaustive result returns the existing booking',
      () async {
    final controller = BookingReconciliationController((
            {required page, required pageSize}) async =>
        _page([_booking('existing')], page: page));
    final result = await controller.reconcile(_draft, current: () => true);
    expect(result, isA<BookingSubmitted>());
    expect((result as BookingSubmitted).id, 'existing');
  });
  test('multiple matching bookings remain unresolved', () async {
    final controller = BookingReconciliationController((
            {required page, required pageSize}) async =>
        _page([_booking('one'), _booking('two')], page: page));
    expect(await controller.reconcile(_draft, current: () => true),
        isA<BookingSubmitMessage>());
  });
  test('hitting the page limit cannot claim that a match is unique', () async {
    var pages = 0;
    final controller = BookingReconciliationController((
        {required page, required pageSize}) async {
      pages++;
      return _page(
          List.generate(
              50,
              (index) =>
                  _booking('$page-$index', match: page == 1 && index == 0)),
          page: page,
          total: 1000);
    });
    expect(await controller.reconcile(_draft, current: () => true),
        isA<BookingSubmitMessage>());
    expect(pages, 10);
  });
  test(
      'a late result after session close is ignored without querying the next page',
      () async {
    var active = true, calls = 0;
    final pending = Completer<BookingListResponse>();
    final controller =
        BookingReconciliationController(({required page, required pageSize}) {
      calls++;
      return pending.future;
    });
    final result = controller.reconcile(_draft, current: () => active);
    active = false;
    pending.complete(_page([_booking('existing')]));
    expect(await result, isA<BookingSubmitIgnored>());
    expect(calls, 1);
  });
}

final _draft = BookingDraft(
    beneficiaryId: 'recipient',
    serviceTypeId: 'service',
    addressId: 'address',
    scheduledStart: DateTime.utc(2026, 10, 15, 7),
    scheduledEnd: DateTime.utc(2026, 10, 15, 9));
BookingModel _booking(String id, {bool match = true}) => BookingModel.fromJson({
      'id': id,
      'beneficiaryId': match ? 'recipient' : 'other',
      'serviceTypeId': 'service',
      'addressId': 'address',
      'scheduledStart': '2026-10-15T07:00:00Z',
      'scheduledEnd': '2026-10-15T09:00:00Z',
    });
BookingListResponse _page(List<BookingModel> items,
        {int page = 1, int? total}) =>
    BookingListResponse(
        items: items, total: total ?? items.length, page: page, pageSize: 50);
