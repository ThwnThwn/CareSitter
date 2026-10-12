import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/features/earnings/domain/withdrawal_rules.dart';

void main() {
  test('withdrawal validation preserves the minimum and balance limits', () {
    expect(WithdrawalRules.validate(double.nan, 200000),
        WithdrawalValidation.invalidAmount);
    expect(WithdrawalRules.validate(double.infinity, 200000),
        WithdrawalValidation.invalidAmount);
    expect(WithdrawalRules.validate(99999, 200000),
        WithdrawalValidation.belowMinimum);
    expect(WithdrawalRules.validate(100001, 100000),
        WithdrawalValidation.insufficientBalance);
    expect(
        WithdrawalRules.validate(100000, 100000), WithdrawalValidation.valid);
  });
}
