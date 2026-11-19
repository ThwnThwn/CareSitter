class EarningsState {
  final double balance;
  final double monthTotal;
  final int completedShifts;
  final List<double> last7Days;

  const EarningsState({
    required this.balance,
    this.monthTotal = 0,
    this.completedShifts = 0,
    this.last7Days = const [0, 0, 0, 0, 0, 0, 0],
  });

  EarningsState copyWith({
    double? balance,
    double? monthTotal,
    int? completedShifts,
    List<double>? last7Days,
  }) {
    return EarningsState(
      balance: balance ?? this.balance,
      monthTotal: monthTotal ?? this.monthTotal,
      completedShifts: completedShifts ?? this.completedShifts,
      last7Days: last7Days ?? this.last7Days,
    );
  }
}
