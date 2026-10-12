import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

({String label, IconData icon, Color color}) walletTransactionInfo(
    String type) {
  switch (type) {
    case 'REFUND':
      return (
        label: 'Hoàn tiền dịch vụ',
        icon: Icons.reply_rounded,
        color: AppColors.primary,
      );
    case 'PAYOUT':
      return (
        label: 'Rút tiền',
        icon: Icons.south_east_rounded,
        color: AppColors.textSecondary,
      );
    default:
      return (
        label: 'Giao dịch ví',
        icon: Icons.receipt_long_outlined,
        color: AppColors.textSecondary,
      );
  }
}

String walletStatusLabel(String status) => switch (status) {
      'POSTED' => 'Hoàn tất',
      'PENDING' => 'Đang xử lý',
      'REVERSED' => 'Đã hoàn tác',
      _ => 'Đang cập nhật',
    };
String walletFormatCurrency(int amount) {
  return formatVnd(amount);
}

String walletFormatDate(DateTime date) =>
    '${formatDate(date, padded: true)} • ${formatClock(date)}';
