import 'package:flutter_riverpod/flutter_riverpod.dart';

class EarningTransaction {
  final String title;
  final String date;
  final String amount;
  final String type; // 'in' or 'out'

  const EarningTransaction({
    required this.title,
    required this.date,
    required this.amount,
    required this.type,
  });
}

class EarningsState {
  final double balance;
  final List<EarningTransaction> transactions;

  const EarningsState({
    required this.balance,
    required this.transactions,
  });

  EarningsState copyWith({
    double? balance,
    List<EarningTransaction>? transactions,
  }) {
    return EarningsState(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
    );
  }
}

String formatCurrency(double amount) {
  final str = amount.round().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(str[i]);
  }
  return buffer.toString();
}

class EarningsNotifier extends StateNotifier<EarningsState> {
  EarningsNotifier()
      : super(const EarningsState(
          balance: 4250000,
          transactions: [
            EarningTransaction(
              title: 'Thanh toán ca bk001',
              date: '26/06/2026',
              amount: '+ 150,000 đ',
              type: 'in',
            ),
            EarningTransaction(
              title: 'Thanh toán ca bk002',
              date: '25/06/2026',
              amount: '+ 200,000 đ',
              type: 'in',
            ),
            EarningTransaction(
              title: 'Rút tiền về ngân hàng',
              date: '20/06/2026',
              amount: '- 2,000,000 đ',
              type: 'out',
            ),
          ],
        ));

  void addEarning(double amount, String bookingId, String beneficiaryName) {
    final formattedAmount = formatCurrency(amount);
    final newTransaction = EarningTransaction(
      title: 'Thanh toán ca $bookingId ($beneficiaryName)',
      date: 'Hôm nay',
      amount: '+ $formattedAmount đ',
      type: 'in',
    );

    state = state.copyWith(
      balance: state.balance + amount,
      transactions: [newTransaction, ...state.transactions],
    );
  }

  bool withdraw(double amount, String bankName, String accountNumber) {
    if (state.balance < amount) return false;
    final formattedAmount = formatCurrency(amount);
    final newTransaction = EarningTransaction(
      title: 'Rút tiền về $bankName ($accountNumber)',
      date: 'Hôm nay',
      amount: '- $formattedAmount đ',
      type: 'out',
    );

    state = state.copyWith(
      balance: state.balance - amount,
      transactions: [newTransaction, ...state.transactions],
    );
    return true;
  }
}

final earningsProvider =
    StateNotifierProvider<EarningsNotifier, EarningsState>((ref) {
  return EarningsNotifier();
});
