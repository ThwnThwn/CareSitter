import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:caregiver_app/core/utils/date_formatter.dart';
import '../../data/models/wallet_activity.dart';

class EarningsTransactionTile extends StatelessWidget {
  const EarningsTransactionTile(
      {super.key, required this.amountColor, required this.activity});
  final Color amountColor;
  final WalletActivity activity;

  String get _title => switch (activity.kind) {
        'CAREGIVER_EARNING' => 'Thu nhập ca chăm sóc',
        'PAYOUT' => 'Chi tiền rút từ ví',
        'PAYOUT_REQUEST' => activity.bankName == null
            ? 'Yêu cầu rút tiền'
            : 'Yêu cầu rút tiền · ${activity.bankName}',
        _ => activity.isCredit ? 'Tiền vào ví' : 'Tiền ra khỏi ví',
      };

  String get _status => switch (activity.status) {
        'PENDING' => 'Chờ duyệt',
        'APPROVED' => 'Đã duyệt',
        'PROCESSING' => 'Đang chuyển tiền',
        'POSTED' => 'Đã ghi nhận',
        'PAID' => 'Đã chuyển tiền',
        'REJECTED' => 'Từ chối',
        'FAILED' => 'Thất bại',
        _ => 'Chưa rõ trạng thái',
      };

  String get _amount {
    final value = formatVnd(activity.amount, round: true);
    if (activity.kind == 'PAYOUT_REQUEST') return value;
    return '${activity.isCredit ? '+' : '−'} $value';
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.control),
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activity.isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: amountColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: AppFontSizes.s15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${formatDate(activity.date, padded: true)} · $_status',
                  style: const TextStyle(
                    fontSize: AppFontSizes.s13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Text(
              _amount,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: AppFontSizes.s15,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ),
        ],
      );
}
