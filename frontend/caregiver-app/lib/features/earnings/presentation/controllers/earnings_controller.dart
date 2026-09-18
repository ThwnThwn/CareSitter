import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/earnings/data/models/earning_model.dart';
import 'package:caregiver_app/features/earnings/data/repositories/earnings_repository.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';

class EarningsController extends StateNotifier<EarningsState> {
  final Ref _ref;

  EarningsController(this._ref)
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

  EarningsRepository get _repository => _ref.read(earningsRepositoryProvider);

  Future<void> refreshWallet() async {
    final isAuthenticated =
        _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuthenticated) return;

    try {
      state = state.copyWith(
        balance: await _repository.getAvailableBalance(),
      );
    } catch (error) {
      // ignore: avoid_print
      print('[EarningsController] Lỗi tải ví caregiver: $error');
    }
  }

  void _rebuildFromBookings(List<ShiftModel> bookings) {
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
      final difference = _dateOnly(now).difference(_dateOnly(date)).inDays;
      if (difference >= 0 && difference < 7) {
        days[6 - difference] += _earningOf(booking);
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
    final newTransaction = EarningTransaction(
      title: 'Thanh toán ca ${_shortId(bookingId)} ($beneficiaryName)',
      date: 'Hôm nay',
      amount: '+ ${formatCurrency(amount)} đ',
      type: 'in',
    );

    state = state.copyWith(
      balance: state.balance + amount,
      monthTotal: state.monthTotal + amount,
      completedShifts: state.completedShifts + 1,
      transactions: [newTransaction, ...state.transactions],
    );
  }

  Future<bool> withdraw(
    double amount,
    String bankName,
    String accountNumber, {
    required String accountHolderName,
  }) async {
    if (state.balance < amount) return false;
    try {
      await _repository.requestWithdrawal(
        amount: amount,
        bankName: bankName,
        accountHolderName: accountHolderName,
        accountNumber: accountNumber,
      );
      final newTransaction = EarningTransaction(
        title: 'Yêu cầu rút tiền về $bankName ($accountNumber)',
        date: 'Hôm nay',
        amount: '- ${formatCurrency(amount)} đ',
        type: 'out',
      );
      state = state.copyWith(
        balance: state.balance - amount,
        transactions: [newTransaction, ...state.transactions],
      );
      await refreshWallet();
      return true;
    } catch (error) {
      // ignore: avoid_print
      print('[EarningsController] withdraw error: $error');
      return false;
    }
  }

  static double _earningOf(ShiftModel booking) {
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
}

final earningsProvider =
    StateNotifierProvider<EarningsController, EarningsState>((ref) {
  return EarningsController(ref);
});
