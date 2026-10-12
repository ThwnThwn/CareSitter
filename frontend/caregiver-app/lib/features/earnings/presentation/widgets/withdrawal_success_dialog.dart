import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:caregiver_app/core/widgets/app_widgets.dart';

/// Hiển thị dialog thông báo rút tiền thành công.
Future<void> showWithdrawalSuccessDialog(
  BuildContext context, {
  required double amount,
  required String bankName,
  required VoidCallback onDismiss,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.md),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 72,
          ),
          const SizedBox(height: AppSpacing.section),
          const Text(
            'Rút tiền thành công!',
            style: TextStyle(
              fontSize: AppFontSizes.s20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Đã tạo yêu cầu rút ${formatVnd(amount, separator: ',', suffix: '', round: true)} đ đến tài khoản $bankName của bạn.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppFontSizes.s14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Quay lại ví',
              onPressed: () {
                Navigator.pop(ctx);
                onDismiss();
              },
            ),
          ),
        ],
      ),
    ),
  );
}
