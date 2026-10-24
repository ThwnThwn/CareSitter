import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';

class SettingsProfileStats extends StatelessWidget {
  const SettingsProfileStats({
    super.key,
    required this.completedShifts,
    required this.monthTotal,
  });

  final int completedShifts;
  final double monthTotal;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.compact),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ProfileStat(
                icon: Icons.event_available_outlined,
                label: 'CA ĐÃ HOÀN THÀNH',
                value: '$completedShifts ca',
              ),
            ),
            const SizedBox(
              height: 42,
              child: VerticalDivider(color: AppColors.border),
            ),
            Expanded(
              child: _ProfileStat(
                icon: Icons.account_balance_wallet_outlined,
                label: 'THU NHẬP THÁNG',
                value: formatVnd(monthTotal, round: true),
              ),
            ),
          ],
        ),
      );
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppFontSizes.s10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppFontSizes.s17,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      );
}
