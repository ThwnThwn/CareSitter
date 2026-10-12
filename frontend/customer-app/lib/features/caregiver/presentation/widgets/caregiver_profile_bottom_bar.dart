import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileBottomBar extends StatelessWidget {
  const CaregiverProfileBottomBar({super.key, required this.caregiver});
  final CaregiverModel caregiver;
  @override
  Widget build(BuildContext context) {
    final rate = caregiver.hourlyRateExpected ?? 85000;
    final price = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Giá thuê',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: AppFontSizes.s12)),
        Text(
          '${formatVnd(rate, separator: ',', suffix: '')}đ/giờ',
          maxLines: 2,
          style: const TextStyle(
              color: AppColors.primary,
              fontSize: AppFontSizes.s20,
              fontWeight: FontWeight.w800),
        ),
      ],
    );
    final action = ElevatedButton(
      onPressed: caregiver.isOnline ? () => context.push('/booking/new') : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      child: Text(
        caregiver.isOnline ? 'Đặt lịch ngay' : 'Hiện đang bận',
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: AppFontSizes.s15, fontWeight: FontWeight.w700),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.compact, AppSpacing.md, AppSpacing.wide),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stackActions =
              constraints.maxWidth < AppBreakpoints.compact || textScale > 1.2;
          if (stackActions) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                price,
                const SizedBox(height: AppSpacing.compact),
                action
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: price),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 2, child: action),
            ],
          );
        },
      ),
    );
  }
}
