import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingShowExtendShiftSheetSelectedHoursFormatCurrencyFields
    extends StatelessWidget {
  const ShiftTrackingShowExtendShiftSheetSelectedHoursFormatCurrencyFields(
      {super.key,
      required this.selectedHours,
      required this.onDecrease,
      required this.onIncrease,
      required this.formatCurrency,
      required this.effectiveHourlyRate,
      required this.action1});
  final int selectedHours;
  final VoidCallback onDecrease, onIncrease;
  final String Function(double) formatCurrency;
  final double effectiveHourlyRate;
  final void Function() action1;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Gia hạn ca chăm sóc',
              style: TextStyle(
                  fontSize: AppFontSizes.s18, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.section),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 32),
                onPressed: selectedHours > 1 ? onDecrease : null,
              ),
              const SizedBox(width: AppSpacing.lg),
              Text('$selectedHours giờ',
                  style: const TextStyle(
                      fontSize: AppFontSizes.s28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
              const SizedBox(width: AppSpacing.lg),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 32),
                onPressed: selectedHours < 4 ? onIncrease : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.inset),
          Text(
              'Phí ước tính: ${formatCurrency(selectedHours * effectiveHourlyRate)}'),
          const SizedBox(height: AppSpacing.section),
          ElevatedButton(
            onPressed: action1,
            child: const Text('Gửi yêu cầu gia hạn'),
          ),
        ],
      );
}
