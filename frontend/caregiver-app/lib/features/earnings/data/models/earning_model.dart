class EarningTransaction {
  final String title;
  final String date;
  final String amount;
  final String type;

  const EarningTransaction({
    required this.title,
    required this.date,
    required this.amount,
    required this.type,
  });
}

class EarningsState {
  final double balance;
  final double monthTotal;
  final int completedShifts;
  final List<double> last7Days;
  final List<EarningTransaction> transactions;

  const EarningsState({
    required this.balance,
    this.monthTotal = 0,
    this.completedShifts = 0,
    this.last7Days = const [0, 0, 0, 0, 0, 0, 0],
    required this.transactions,
  });

  EarningsState copyWith({
    double? balance,
    double? monthTotal,
    int? completedShifts,
    List<double>? last7Days,
    List<EarningTransaction>? transactions,
  }) {
    return EarningsState(
      balance: balance ?? this.balance,
      monthTotal: monthTotal ?? this.monthTotal,
      completedShifts: completedShifts ?? this.completedShifts,
      last7Days: last7Days ?? this.last7Days,
      transactions: transactions ?? this.transactions,
    );
  }
}
