import 'package:flutter/material.dart';

import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/core/utils/date_formatter.dart';
import 'package:caresitter_customer/features/refunds/data/models/refund_record.dart';

class RefundCard extends StatelessWidget {
  const RefundCard({
    super.key,
    required this.refund,
    required this.onRetry,
    required this.onSupport,
  });

  final RefundRecord refund;
  final VoidCallback onRetry;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo(refund.status);
    return Semantics(
      container: true,
      label: '${status.label}, ${formatVnd(refund.amount)}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _RefundHeader(status: status, provider: refund.provider),
          _RefundDetails(refund: refund),
          _RefundActions(
            needsSupport: refund.needsSupport,
            onRetry: onRetry,
            onSupport: onSupport,
          ),
        ]),
      ),
    );
  }
}

class _RefundHeader extends StatelessWidget {
  const _RefundHeader({required this.status, required this.provider});

  final _RefundStatusInfo status;
  final String provider;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.control,
            vertical: AppSpacing.tight,
          ),
          decoration: BoxDecoration(
            color: status.background,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(status.icon, size: 16, color: status.foreground),
            const SizedBox(width: AppSpacing.tight),
            Text(status.label,
                style: TextStyle(
                  color: status.foreground,
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w700,
                )),
          ]),
        ),
        const Spacer(),
        Text(provider,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s12,
              fontWeight: FontWeight.w600,
            )),
      ]);
}

class _RefundDetails extends StatelessWidget {
  const _RefundDetails({required this.refund});

  final RefundRecord refund;

  @override
  Widget build(BuildContext context) {
    final bookingRef = refund.bookingId.length > 8
        ? refund.bookingId.substring(0, 8).toUpperCase()
        : refund.bookingId.toUpperCase();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: AppSpacing.md),
      Text(formatVnd(refund.amount),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppFontSizes.s22,
            fontWeight: FontWeight.w800,
          )),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Đơn #$bookingRef • ${_reasonLabel(refund.reason)}',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppFontSizes.s13,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Yêu cầu lúc ${formatClock(refund.requestedAt)} • ${formatDate(refund.requestedAt, padded: true)}',
        style: const TextStyle(
          color: AppColors.textHint,
          fontSize: AppFontSizes.s12,
        ),
      ),
    ]);
  }
}

class _RefundActions extends StatelessWidget {
  const _RefundActions({
    required this.needsSupport,
    required this.onRetry,
    required this.onSupport,
  });

  final bool needsSupport;
  final VoidCallback onRetry;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Row(children: [
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
          ),
          if (needsSupport) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSupport,
                icon: const Icon(Icons.headset_mic_outlined, size: 18),
                label: const Text('Liên hệ hỗ trợ'),
              ),
            ),
          ],
        ]),
      );
}

typedef _RefundStatusInfo = ({
  String label,
  IconData icon,
  Color foreground,
  Color background,
});

_RefundStatusInfo _statusInfo(String status) => switch (status) {
      'SUCCEEDED' => (
          label: 'Đã hoàn',
          icon: Icons.check_circle_outline,
          foreground: AppColors.success,
          background: AppColors.successLight,
        ),
      'MANUAL_REQUIRED' => (
          label: 'Cần xử lý thủ công',
          icon: Icons.support_agent_outlined,
          foreground: AppColors.warning,
          background: AppColors.warningLight,
        ),
      'FAILED' => (
          label: 'Thất bại',
          icon: Icons.error_outline,
          foreground: AppColors.error,
          background: AppColors.errorLight,
        ),
      _ => (
          label: 'Đang xử lý',
          icon: Icons.schedule_rounded,
          foreground: AppColors.info,
          background: AppColors.infoLight,
        ),
    };

String _reasonLabel(String reason) => switch (reason) {
      'NO_CAREGIVER_AVAILABLE' => 'Không tìm được người chăm sóc',
      'CUSTOMER_CANCELLATION' ||
      'CUSTOMER_PRESTART_CANCELLATION' =>
        'Hủy lịch chăm sóc',
      final value when value.startsWith('DISPUTE_') => 'Kết quả khiếu nại',
      _ => 'Hoàn tiền dịch vụ',
    };
