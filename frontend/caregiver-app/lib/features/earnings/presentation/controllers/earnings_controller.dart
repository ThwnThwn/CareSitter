import 'package:caregiver_app/core/utils/date_formatter.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'withdrawal_result.dart';
import '../../domain/withdrawal_rules.dart';
export 'withdrawal_result.dart';
import 'package:caregiver_app/core/error/app_exception.dart';

import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/features/earnings/data/models/earning_model.dart';
import 'package:caregiver_app/features/earnings/data/repositories/earnings_repository.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';

class EarningsController extends StateNotifier<EarningsState> {
  final Ref _ref;
  int _walletGeneration = 0;
  bool _withdrawing = false;
  ({
    double amount,
    String bank,
    String bankBin,
    String holder,
    String account,
    String key
  })? _pendingWithdrawal;

  EarningsController(this._ref)
      : super(const EarningsState(balance: 0, transactions: [])) {
    _ref.listen(shiftsProvider, (previous, next) {
      _rebuildFromBookings(next);
    });
    refreshWallet();
    _rebuildFromBookings(_ref.read(shiftsProvider));
  }

  EarningsRepository get _repository => _ref.read(earningsRepositoryProvider);

  Future<void> refreshWallet() async {
    if (!mounted) return;
    final generation = ++_walletGeneration;
    final isAuthenticated =
        _ref.read(authStateProvider).value?.isAuthenticated ?? false;
    if (!isAuthenticated) return;

    try {
      final balance = await _repository.getAvailableBalance();
      if (!mounted || generation != _walletGeneration) return;
      state = state.copyWith(balance: balance);
    } catch (error) {
      // ignore: avoid_print
      print('[EarningsController] Lỗi tải ví caregiver: $error');
    }
  }

  void _rebuildFromBookings(List<ShiftModel> bookings) {
    if (!mounted) return;
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
        amount:
            '+ ${formatVnd(amount, separator: ',', suffix: '', round: true)} đ',
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
    if (!mounted) return;
    final newTransaction = EarningTransaction(
      title: 'Thanh toán ca ${_shortId(bookingId)} ($beneficiaryName)',
      date: 'Hôm nay',
      amount:
          '+ ${formatVnd(amount, separator: ',', suffix: '', round: true)} đ',
      type: 'in',
    );

    state = state.copyWith(
      balance: state.balance + amount,
      monthTotal: state.monthTotal + amount,
      completedShifts: state.completedShifts + 1,
      transactions: [newTransaction, ...state.transactions],
    );
  }

  Future<WithdrawalResult> withdraw(
    double amount, {
    required String bankName,
    required String bankBin,
    required String accountNumber,
    required String accountHolderName,
  }) async {
    if (!mounted || _withdrawing) {
      return WithdrawalResult.ignored;
    }
    final pending = _pendingWithdrawal;
    if (pending != null &&
        (pending.amount != amount ||
            pending.bank != bankName ||
            pending.bankBin != bankBin ||
            pending.holder != accountHolderName ||
            pending.account != accountNumber)) {
      return WithdrawalResult.changedPayload;
    }
    if (pending == null) {
      final validation = WithdrawalRules.validate(amount, state.balance);
      if (validation != WithdrawalValidation.valid) {
        return switch (validation) {
          WithdrawalValidation.belowMinimum => WithdrawalResult.belowMinimum,
          WithdrawalValidation.insufficientBalance =>
            WithdrawalResult.insufficientBalance,
          _ => WithdrawalResult.rejected,
        };
      }
    }
    final key = pending?.key ?? const Uuid().v4();
    _pendingWithdrawal = (
      amount: amount,
      bank: bankName,
      bankBin: bankBin,
      holder: accountHolderName,
      account: accountNumber,
      key: key
    );
    _withdrawing = true;
    try {
      await _repository.requestWithdrawal(
        amount: amount,
        bankName: bankName,
        bankBin: bankBin,
        accountHolderName: accountHolderName,
        accountNumber: accountNumber,
        idempotencyKey: key,
      );
      if (!mounted) return WithdrawalResult.ignored;
      final newTransaction = EarningTransaction(
        title: 'Yêu cầu rút tiền về $bankName ($accountNumber)',
        date: 'Hôm nay',
        amount:
            '- ${formatVnd(amount, separator: ',', suffix: '', round: true)} đ',
        type: 'out',
      );
      state = state.copyWith(
        transactions: [newTransaction, ...state.transactions],
      );
      _pendingWithdrawal = null;
      await refreshWallet();
      return mounted ? WithdrawalResult.submitted : WithdrawalResult.ignored;
    } catch (error) {
      if (mounted && error is AppApiException && !error.outcomeMayBeUnknown) {
        _pendingWithdrawal = null;
      }
      // ignore: avoid_print
      print('[EarningsController] withdraw error: $error');
      if (!mounted) return WithdrawalResult.ignored;
      return error is AppApiException && !error.outcomeMayBeUnknown
          ? WithdrawalResult.rejected
          : WithdrawalResult.unknown;
    } finally {
      _withdrawing = false;
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

  static String _formatDate(DateTime? value) =>
      value == null ? 'Chưa rõ ngày' : formatDate(value, padded: true);

  static String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;
}

final earningsProvider =
    StateNotifierProvider<EarningsController, EarningsState>((ref) {
  ref.watch(authStateProvider.select(
      (session) => (session.value?.userId, session.value?.isAuthenticated)));
  return EarningsController(ref);
});
