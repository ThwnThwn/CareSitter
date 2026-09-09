import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_constants.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/mock/mock_data.dart';
import '../../../shifts/presentation/providers/shifts_provider.dart';

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
  final Ref _ref;

  EarningsNotifier(this._ref)
      : super(const EarningsState(balance: 0, transactions: [])) {
    _ref.listen(authStateProvider, (previous, next) {
      if (next.value?.isAuthenticated ?? false) {
        refreshWallet();
      } else {
        state = const EarningsState(balance: 0, transactions: []);
      }
    });
    _ref.listen(shiftsProvider, (previous, next) {
      _rebuildFromBookings(next);
    });
    refreshWallet();
    _rebuildFromBookings(_ref.read(shiftsProvider));
  }

  DioClient get _dio => _ref.read(dioClientProvider);

  Future<void> refreshWallet() async {
    if (kDebugBypassAuth) return;

    final isAuth = _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuth) return;

    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiPaths.wallet);
      final data = response.data ?? {};
      state = state.copyWith(
        balance: _num(data['availableBalance'] ?? data['AvailableBalance']),
      );
    } catch (e) {
      // ignore: avoid_print
      print('[EarningsNotifier] Lỗi tải ví caregiver: $e');
    }
  }

  void _rebuildFromBookings(List<MockBooking> bookings) {
    final completed =
        bookings.where((booking) => booking.status == 'completed').toList()
          ..sort((a, b) {
            final aDate =
                a.scheduledStart ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                b.scheduledStart ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

    final now = DateTime.now();
    final monthTotal = completed.where((booking) {
      final date = booking.scheduledStart;
      return date != null && date.year == now.year && date.month == now.month;
    }).fold<double>(0, (sum, booking) => sum + _earningOf(booking));

    final days = List<double>.filled(7, 0);
    for (final booking in completed) {
      final date = booking.scheduledStart;
      if (date == null) continue;
      final diff = _dateOnly(now).difference(_dateOnly(date)).inDays;
      if (diff >= 0 && diff < 7) {
        days[6 - diff] += _earningOf(booking);
      }
    }

    final transactions = completed.map((booking) {
      final amount = _earningOf(booking);
      return EarningTransaction(
        title:
            'Thanh toán ca ${_shortId(booking.id)} (${booking.beneficiaryName})',
        date: _formatDate(booking.scheduledStart),
        amount: '+ ${formatCurrency(amount)} đ',
        type: 'in',
      );
    }).toList(growable: false);

    state = state.copyWith(
      monthTotal: monthTotal,
      completedShifts: completed.length,
      last7Days: days,
      transactions: transactions,
    );
  }

  void addEarning(double amount, String bookingId, String beneficiaryName) {
    final formattedAmount = formatCurrency(amount);
    final newTransaction = EarningTransaction(
      title: 'Thanh toán ca ${_shortId(bookingId)} ($beneficiaryName)',
      date: 'Hôm nay',
      amount: '+ $formattedAmount đ',
      type: 'in',
    );

    state = state.copyWith(
      balance: state.balance + amount,
      monthTotal: state.monthTotal + amount,
      completedShifts: state.completedShifts + 1,
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

  static double _earningOf(MockBooking booking) {
    return booking.caregiverEarning > 0
        ? booking.caregiverEarning
        : booking.totalPrice;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'Chưa rõ ngày';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  static String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

  static double _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

final earningsProvider =
    StateNotifierProvider<EarningsNotifier, EarningsState>((ref) {
  return EarningsNotifier(ref);
});
