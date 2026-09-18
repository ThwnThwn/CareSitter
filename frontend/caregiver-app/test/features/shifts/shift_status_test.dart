import 'package:flutter_test/flutter_test.dart';

import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

void main() {
  test('normalizes backend shift status values', () {
    expect(
      ShiftStatus.fromApi('CAREGIVER_EN_ROUTE'),
      ShiftStatus.caregiverEnRoute,
    );
    expect(
      ShiftStatus.fromApi('checkout-pending-review'),
      ShiftStatus.checkoutPendingReview,
    );
  });

  test('uses unknown for unsupported status values', () {
    expect(ShiftStatus.fromApi('future_state'), ShiftStatus.unknown);
    expect(ShiftStatus.fromApi(null), ShiftStatus.unknown);
  });
}
