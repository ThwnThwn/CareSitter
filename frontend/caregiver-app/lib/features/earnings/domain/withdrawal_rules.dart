enum WithdrawalValidation {
  valid,
  invalidAmount,
  belowMinimum,
  insufficientBalance
}

class WithdrawalRules {
  static const minimumVnd = 100000;
  static WithdrawalValidation validate(double amount, double availableBalance) {
    if (!amount.isFinite || amount <= 0) {
      return WithdrawalValidation.invalidAmount;
    }
    if (amount < minimumVnd) return WithdrawalValidation.belowMinimum;
    if (amount > availableBalance) {
      return WithdrawalValidation.insufficientBalance;
    }
    return WithdrawalValidation.valid;
  }
}
